package main

import (
    "flag"
    "fmt"
    "html/template"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/gorilla/websocket"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    addr = flag.String("addr", ":8080", "http service address")
    
    // Prometheus метрики
    clientsConnected = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "websocket_clients_connected",
        Help: "Number of currently connected WebSocket clients",
    })
    
    messagesReceived = promauto.NewCounter(prometheus.CounterOpts{
        Name: "websocket_messages_received_total",
        Help: "Total number of messages received",
    })
    
    messagesSent = promauto.NewCounter(prometheus.CounterOpts{
        Name: "websocket_messages_sent_total",
        Help: "Total number of messages sent",
    })
    
    httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "http_requests_total",
        Help: "Total number of HTTP requests",
    }, []string{"method", "endpoint", "status"})
    
    httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "http_request_duration_seconds",
        Help:    "Duration of HTTP requests",
        Buckets: []float64{0.1, 0.5, 1, 2, 5},
    }, []string{"method", "endpoint"})
)

var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        return true
    },
}

func serveHome(w http.ResponseWriter, r *http.Request) {
    if r.URL.Path != "/" {
        http.Error(w, "Not found", http.StatusNotFound)
        httpRequests.WithLabelValues(r.Method, r.URL.Path, "404").Inc()
        return
    }
    if r.Method != "GET" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        httpRequests.WithLabelValues(r.Method, r.URL.Path, "405").Inc()
        return
    }
    
    start := time.Now()
    httpRequests.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
    
    homeTemplate, err := template.ParseFiles("home.html")
    if err != nil {
        log.Printf("Error loading template: %v", err)
        http.Error(w, "Internal Server Error", http.StatusInternalServerError)
        return
    }
    
    homeTemplate.Execute(w, "ws://"+r.Host+"/ws")
    
    duration := time.Since(start).Seconds()
    httpDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
}

func serveHealth(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, `{"status": "healthy", "timestamp": "%s", "service": "go-websocket-chat"}`, time.Now().Format(time.RFC3339))
    
    duration := time.Since(start).Seconds()
    httpRequests.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
    httpDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
}

func serveMetrics(w http.ResponseWriter, r *http.Request) {
    promhttp.Handler().ServeHTTP(w, r)
    httpRequests.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println("Upgrade error:", err)
        httpRequests.WithLabelValues(r.Method, r.URL.Path, "500").Inc()
        return
    }
    
    client := &Client{
        hub:  hub,
        conn: conn,
        send: make(chan []byte, 256),
    }
    client.hub.register <- client
    
    clientsConnected.Inc()
    httpRequests.WithLabelValues(r.Method, r.URL.Path, "101").Inc()
    
    duration := time.Since(start).Seconds()
    httpDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
    
    go client.writePump()
    client.readPump()
}

func main() {
    flag.Parse()
    
    // Логирование
    log.SetOutput(os.Stdout)
    log.Println("Starting Go WebSocket Chat Server...")
    
    hub := newHub()
    go hub.run()
    
    // HTTP маршруты
    http.HandleFunc("/", serveHome)
    http.HandleFunc("/health", serveHealth)
    http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
        serveWs(hub, w, r)
    })
    
    // Метрики Prometheus
    http.Handle("/metrics", promhttp.Handler())
    
    // Статические файлы
    fs := http.FileServer(http.Dir("./static"))
    http.Handle("/static/", http.StripPrefix("/static/", fs))
    
    log.Printf("Server starting on %s", *addr)
    log.Printf("Health check available at http://localhost%s/health", *addr)
    log.Printf("Metrics available at http://localhost%s/metrics", *addr)
    
    if err := http.ListenAndServe(*addr, nil); err != nil {
        log.Fatal("ListenAndServe: ", err)
    }
}
