#!/bin/bash

# Swift MCP Server Integration Test
# Tests both HTTP and STDIO modes with real MCP protocol communication
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_BINARY="$SCRIPT_DIR/.build/release/swift-mcp-server"
HTTP_PORT=8080
TEST_WORKSPACE="$SCRIPT_DIR"
TIMEOUT=30

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}Swift MCP Server Integration Tests${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo
}

print_test() {
    echo -e "${BLUE}🧪 $1${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

cleanup() {
    # Kill any running servers
    pkill -f "swift-mcp-server" 2>/dev/null || true
    
    # Remove temporary files
    rm -f /tmp/mcp-test-*.json
    rm -f /tmp/mcp-stdio-*.log
}

# Trap cleanup on exit
trap cleanup EXIT

test_binary_exists() {
    print_test "Testing server binary exists"
    
    if [ -f "$SERVER_BINARY" ]; then
        print_success "Server binary found at $SERVER_BINARY"
        return 0
    else
        print_error "Server binary not found. Run 'swift build -c release' first"
        return 1
    fi
}

test_help_command() {
    print_test "Testing help command"
    
    if "$SERVER_BINARY" --help > /tmp/mcp-help.log 2>&1; then
        if grep -q "USAGE" /tmp/mcp-help.log; then
            print_success "Help command works correctly"
            return 0
        else
            print_error "Help command output malformed"
            return 1
        fi
    else
        print_error "Help command failed"
        return 1
    fi
}

test_http_server_startup() {
    print_test "Testing HTTP server startup"
    
    # Start server in background
    "$SERVER_BINARY" \
        --transport http \
        --port $HTTP_PORT \
        --workspace "$TEST_WORKSPACE" \
        --log-level debug \
        > /tmp/mcp-http.log 2>&1 &
    
    local server_pid=$!
    
    # Wait for startup
    sleep 3
    
    # Check if process is running
    if kill -0 $server_pid 2>/dev/null; then
        print_success "HTTP server started on port $HTTP_PORT"
        
        # Test health endpoint
        if curl -s -f "http://localhost:$HTTP_PORT/health" > /dev/null; then
            print_success "Health endpoint responding"
        else
            print_warning "Health endpoint not responding"
        fi
        
        # Cleanup
        kill $server_pid 2>/dev/null || true
        return 0
    else
        print_error "HTTP server failed to start"
        cat /tmp/mcp-http.log
        return 1
    fi
}

test_stdio_communication() {
    print_test "Testing STDIO communication"
    
    # Create MCP initialize request
    local init_request='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}'
    
    # Start server and send request
    echo "$init_request" | timeout $TIMEOUT "$SERVER_BINARY" \
        --transport stdio \
        --workspace "$TEST_WORKSPACE" \
        --log-level debug \
        > /tmp/mcp-stdio-response.json 2>/tmp/mcp-stdio.log
    
    if [ $? -eq 0 ]; then
        # Check if response contains expected fields
        if grep -q '"result"' /tmp/mcp-stdio-response.json && \
           grep -q '"capabilities"' /tmp/mcp-stdio-response.json; then
            print_success "STDIO communication successful"
            print_info "Server capabilities detected in response"
            return 0
        else
            print_error "Invalid MCP response format"
            echo "Response: $(cat /tmp/mcp-stdio-response.json)"
            return 1
        fi
    else
        print_error "STDIO communication failed"
        echo "Error log: $(cat /tmp/mcp-stdio.log)"
        return 1
    fi
}

test_workspace_analysis() {
    print_test "Testing workspace analysis capabilities"
    
    # Create a test request for listing tools
    local tools_request='{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}'
    
    # Send request via STDIO
    echo "$tools_request" | timeout $TIMEOUT "$SERVER_BINARY" \
        --transport stdio \
        --workspace "$TEST_WORKSPACE" \
        --log-level info \
        > /tmp/mcp-tools-response.json 2>/tmp/mcp-tools.log
    
    if [ $? -eq 0 ]; then
        if grep -q '"tools"' /tmp/mcp-tools-response.json; then
            local tool_count=$(grep -o '"name"' /tmp/mcp-tools-response.json | wc -l)
            print_success "Workspace analysis working - $tool_count tools available"
            return 0
        else
            print_warning "No tools found in response"
            return 1
        fi
    else
        print_error "Workspace analysis failed"
        return 1
    fi
}

test_concurrent_connections() {
    print_test "Testing concurrent HTTP connections"
    
    # Start HTTP server
    "$SERVER_BINARY" \
        --transport http \
        --port $HTTP_PORT \
        --workspace "$TEST_WORKSPACE" \
        > /tmp/mcp-concurrent.log 2>&1 &
    
    local server_pid=$!
    sleep 3
    
    if kill -0 $server_pid 2>/dev/null; then
        # Make multiple concurrent requests
        for i in {1..5}; do
            curl -s "http://localhost:$HTTP_PORT/health" > /tmp/mcp-req-$i.log &
        done
        
        # Wait for all requests to complete
        wait
        
        # Check if all requests succeeded
        local success_count=0
        for i in {1..5}; do
            if [ -s /tmp/mcp-req-$i.log ]; then
                success_count=$((success_count + 1))
            fi
        done
        
        if [ $success_count -eq 5 ]; then
            print_success "All $success_count concurrent requests succeeded"
        else
            print_warning "Only $success_count out of 5 requests succeeded"
        fi
        
        # Cleanup
        kill $server_pid 2>/dev/null || true
        return 0
    else
        print_error "Failed to start server for concurrent test"
        return 1
    fi
}

test_error_handling() {
    print_test "Testing error handling"
    
    # Test invalid JSON request
    local invalid_request='{"jsonrpc": "2.0", "id": 3, "method": "invalid_method"'
    
    echo "$invalid_request" | timeout 10 "$SERVER_BINARY" \
        --transport stdio \
        --workspace "$TEST_WORKSPACE" \
        > /tmp/mcp-error-response.json 2>/tmp/mcp-error.log
    
    # Should handle gracefully without crashing
    if [ $? -ne 0 ]; then
        print_success "Server correctly rejected invalid request"
        return 0
    else
        # Check if error response was returned
        if grep -q '"error"' /tmp/mcp-error-response.json; then
            print_success "Server returned proper error response"
            return 0
        else
            print_warning "Server accepted invalid request"
            return 1
        fi
    fi
}

run_performance_test() {
    print_test "Testing performance under load"
    
    # Start HTTP server
    "$SERVER_BINARY" \
        --transport http \
        --port $HTTP_PORT \
        --workspace "$TEST_WORKSPACE" \
        > /tmp/mcp-perf.log 2>&1 &
    
    local server_pid=$!
    sleep 3
    
    if kill -0 $server_pid 2>/dev/null; then
        local start_time=$(date +%s)
        
        # Make 50 quick requests
        for i in {1..50}; do
            curl -s "http://localhost:$HTTP_PORT/health" > /dev/null &
            if [ $((i % 10)) -eq 0 ]; then
                wait  # Batch processing
            fi
        done
        wait
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $duration -lt 10 ]; then
            print_success "Performance test completed in ${duration}s (50 requests)"
        else
            print_warning "Performance test slow: ${duration}s for 50 requests"
        fi
        
        # Cleanup
        kill $server_pid 2>/dev/null || true
        return 0
    else
        print_error "Failed to start server for performance test"
        return 1
    fi
}

print_summary() {
    echo
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "Total tests run: ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
        echo
        echo -e "${RED}❌ Some tests failed. Check logs for details.${NC}"
        return 1
    else
        echo -e "${GREEN}Tests failed: 0${NC}"
        echo
        echo -e "${GREEN}🎉 All tests passed! Server is ready for production.${NC}"
        return 0
    fi
}

# Main execution
main() {
    print_header
    
    # Prerequisites
    if ! test_binary_exists; then
        echo -e "${RED}Cannot run tests without server binary${NC}"
        exit 1
    fi
    
    # Core functionality tests
    test_help_command || true
    test_http_server_startup || true  
    test_stdio_communication || true
    test_workspace_analysis || true
    
    # Advanced tests
    test_concurrent_connections || true
    test_error_handling || true
    run_performance_test || true
    
    # Summary
    print_summary
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi