// main.go
package main

import (
    "net/http"
    "time"
    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    // Prometheus metrics
    requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name: "http_request_duration_seconds",
        Help: "Duration of HTTP requests",
        Buckets: prometheus.ExponentialBuckets(0.001, 2, 15), // From 1ms to ~16s
    }, []string{"endpoint"})

    throughputBytes = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "network_throughput_bytes_total",
        Help: "Total number of bytes transferred",
    }, []string{"direction"})

    latencyHistogram = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name: "network_latency_seconds",
        Help: "Network latency in seconds",
        Buckets: prometheus.LinearBuckets(0.001, 0.001, 10), // From 1ms to 10ms
    }, []string{"operation"})

    connectionErrors = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "network_connection_errors_total",
        Help: "Total number of network connection errors",
    }, []string{"error_type"})
)

// Test payload generator
func generatePayload(size int) []byte {
    payload := make([]byte, size)
    for i := range payload {
        payload[i] = byte(i % 256)
    }
    return payload
}

func main() {
    r := gin.Default()

    // Prometheus metrics endpoint
    r.GET("/metrics", gin.WrapH(promhttp.Handler()))

    // Latency test endpoint
    r.GET("/ping", func(c *gin.Context) {
        start := time.Now()
        c.String(http.StatusOK, "pong")
        duration := time.Since(start)
        latencyHistogram.WithLabelValues("ping").Observe(duration.Seconds())
    })

    // Throughput test endpoint
    r.POST("/upload", func(c *gin.Context) {
        start := time.Now()
        
        // Read the entire body
        body, err := c.GetRawData()
        if err != nil {
            connectionErrors.WithLabelValues("upload_read_error").Inc()
            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
            return
        }

        throughputBytes.WithLabelValues("upload").Add(float64(len(body)))
        duration := time.Since(start)
        requestDuration.WithLabelValues("upload").Observe(duration.Seconds())
        
        c.JSON(http.StatusOK, gin.H{
            "size": len(body),
            "duration_ms": duration.Milliseconds(),
        })
    })

    // Download test endpoint
    r.GET("/download/:size", func(c *gin.Context) {
        size := 1024 * 1024 // Default 1MB
        start := time.Now()

        payload := generatePayload(size)
        throughputBytes.WithLabelValues("download").Add(float64(size))
        
        c.Data(http.StatusOK, "application/octet-stream", payload)
        duration := time.Since(start)
        requestDuration.WithLabelValues("download").Observe(duration.Seconds())
    })

    r.Run(":8080")
}
