#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting E2E Integration Tests..."
echo "===================================="

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
USER_SERVICE_URL="${USER_SERVICE_URL:-http://localhost:8001}"
TODO_SERVICE_URL="${TODO_SERVICE_URL:-http://localhost:8002}"
TEST_USER="e2e-test-user-$(date +%s)"
TEST_EMAIL="e2e-test-${TEST_USER}@example.com"
TEST_PASSWORD="TestPassword123!"

# Counters
PASSED=0
FAILED=0

# Helper functions
print_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ PASSED:${NC} $1"
    PASSED=$((PASSED + 1))
}

print_error() {
    echo -e "${RED}❌ FAILED:${NC} $1"
    FAILED=$((FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

# Wait for services to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_info "Waiting for ${service_name} to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "${url}/health" > /dev/null 2>&1; then
            print_success "${service_name} is ready!"
            return 0
        fi
        echo "Attempt ${attempt}/${max_attempts}... waiting"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "${service_name} failed to start within timeout"
    return 1
}

# Test functions
test_health_checks() {
    print_test "Testing health endpoints"
    
    # User service health
    if curl -f -s "${USER_SERVICE_URL}/health" | grep -q "user-service"; then
        print_success "User service health check OK"
    else
        print_error "User service health check failed"
        return 1
    fi
    
    # Todo service health
    if curl -f -s "${TODO_SERVICE_URL}/health" | grep -q "todo-service"; then
        print_success "Todo service health check OK"
    else
        print_error "Todo service health check failed"
        return 1
    fi
}

test_user_registration() {
    print_test "Testing user registration"
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "${USER_SERVICE_URL}/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        print_success "User registration successful"
        print_info "User ID: $(echo $body | grep -o '"id":[0-9]*' | cut -d: -f2)"
        return 0
    else
        print_error "User registration failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_user_login() {
    print_test "Testing user login and JWT token generation"
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "${USER_SERVICE_URL}/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"${TEST_PASSWORD}\"}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        # Extract token using grep and cut (works without jq)
        TOKEN=$(echo "$body" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$TOKEN" ]; then
            print_success "User login successful, JWT token received"
            print_info "Token (first 20 chars): ${TOKEN:0:20}..."
            export JWT_TOKEN="$TOKEN"
            return 0
        else
            print_error "Token extraction failed"
            echo "Response: $body"
            return 1
        fi
    else
        print_error "User login failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_token_verification() {
    print_test "Testing JWT token verification"
    
    if [ -z "$JWT_TOKEN" ]; then
        print_error "No JWT token available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X GET "${USER_SERVICE_URL}/verify" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        print_success "JWT token verification successful"
        print_info "User: $(echo $body | grep -o '"username":"[^"]*"' | cut -d'"' -f4)"
        return 0
    else
        print_error "Token verification failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_create_todo() {
    print_test "Testing todo creation (User-service ↔ Todo-service integration)"
    
    if [ -z "$JWT_TOKEN" ]; then
        print_error "No JWT token available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "${TODO_SERVICE_URL}/todos" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"title":"E2E Test Todo","description":"This is an integration test todo"}')
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        TODO_ID=$(echo "$body" | grep -o '"id":[0-9]*' | cut -d: -f2)
        print_success "Todo created successfully"
        print_info "Todo ID: $TODO_ID"
        export TODO_ID
        return 0
    else
        print_error "Todo creation failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_list_todos() {
    print_test "Testing todo list retrieval"
    
    if [ -z "$JWT_TOKEN" ]; then
        print_error "No JWT token available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X GET "${TODO_SERVICE_URL}/todos" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        # Check if our todo is in the list
        if echo "$body" | grep -q "E2E Test Todo"; then
            print_success "Todo list retrieved successfully, our todo is present"
            return 0
        else
            print_error "Todo list retrieved but our todo is missing"
            echo "Response: $body"
            return 1
        fi
    else
        print_error "Todo list retrieval failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_get_specific_todo() {
    print_test "Testing specific todo retrieval"
    
    if [ -z "$JWT_TOKEN" ] || [ -z "$TODO_ID" ]; then
        print_error "No JWT token or TODO_ID available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X GET "${TODO_SERVICE_URL}/todos/${TODO_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q "E2E Test Todo"; then
            print_success "Specific todo retrieved successfully"
            return 0
        else
            print_error "Todo retrieved but content mismatch"
            echo "Response: $body"
            return 1
        fi
    else
        print_error "Specific todo retrieval failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_update_todo() {
    print_test "Testing todo update"
    
    if [ -z "$JWT_TOKEN" ] || [ -z "$TODO_ID" ]; then
        print_error "No JWT token or TODO_ID available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X PUT "${TODO_SERVICE_URL}/todos/${TODO_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"title":"E2E Test Todo (Updated)","completed":true}')
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q "Updated"; then
            print_success "Todo updated successfully"
            return 0
        else
            print_error "Todo update response unexpected"
            echo "Response: $body"
            return 1
        fi
    else
        print_error "Todo update failed (HTTP $http_code)"
        echo "Response: $body"
        return 1
    fi
}

test_delete_todo() {
    print_test "Testing todo deletion"
    
    if [ -z "$JWT_TOKEN" ] || [ -z "$TODO_ID" ]; then
        print_error "No JWT token or TODO_ID available"
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" -X DELETE "${TODO_SERVICE_URL}/todos/${TODO_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        print_success "Todo deleted successfully"
        return 0
    else
        print_error "Todo deletion failed (HTTP $http_code)"
        return 1
    fi
}

test_unauthorized_access() {
    print_test "Testing unauthorized access (negative test)"
    
    local response=$(curl -s -w "\n%{http_code}" -X GET "${TODO_SERVICE_URL}/todos")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "401" ]; then
        print_success "Unauthorized access properly rejected"
        return 0
    else
        print_error "Unauthorized access not properly handled (HTTP $http_code)"
        return 1
    fi
}

test_invalid_token() {
    print_test "Testing invalid JWT token (negative test)"
    
    local response=$(curl -s -w "\n%{http_code}" -X GET "${TODO_SERVICE_URL}/todos" \
        -H "Authorization: Bearer invalid-token-12345")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "401" ]; then
        print_success "Invalid token properly rejected"
        return 0
    else
        print_error "Invalid token not properly handled (HTTP $http_code)"
        return 1
    fi
}

# Main test execution
main() {
    echo ""
    echo "🔍 Test Configuration:"
    echo "   User Service: $USER_SERVICE_URL"
    echo "   Todo Service: $TODO_SERVICE_URL"
    echo "   Test User: $TEST_USER"
    echo ""
    
    # Wait for services
    wait_for_service "$USER_SERVICE_URL" "User Service" || exit 1
    wait_for_service "$TODO_SERVICE_URL" "Todo Service" || exit 1
    
    echo ""
    echo "🧪 Running E2E Tests..."
    echo "===================================="
    
    # Run all tests in sequence (order matters - they build on each other)
    test_health_checks || true
    test_user_registration || exit 1
    test_user_login || exit 1
    test_token_verification || true
    test_unauthorized_access || true
    test_invalid_token || true
    test_create_todo || exit 1
    test_list_todos || true
    test_get_specific_todo || true
    test_update_todo || true
    test_delete_todo || true
    
    # Summary
    echo ""
    echo "===================================="
    echo "📊 Test Summary"
    echo "===================================="
    echo -e "${GREEN}✅ Passed: $PASSED${NC}"
    echo -e "${RED}❌ Failed: $FAILED${NC}"
    echo "   Total:  $((PASSED + FAILED))"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All E2E tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some E2E tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main
