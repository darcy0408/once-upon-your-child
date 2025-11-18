#!/usr/bin/env python3
"""
Load testing script for Story Weaver API
Tests concurrent requests to ensure scalability
"""

import asyncio
import aiohttp
import time
import statistics
from typing import List, Dict

async def make_request(session: aiohttp.ClientSession, url: str, data: Dict) -> Dict:
    """Make a single API request and return timing/response data"""
    start_time = time.time()

    try:
        async with session.post(url, json=data) as response:
            response_time = time.time() - start_time
            status = response.status
            response_text = await response.text()

            return {
                'status': status,
                'response_time': response_time,
                'success': status == 200,
                'error': None if status == 200 else response_text[:200]  # Truncate long errors
            }
    except Exception as e:
        response_time = time.time() - start_time
        return {
            'status': None,
            'response_time': response_time,
            'success': False,
            'error': str(e)
        }

async def load_test(base_url: str, num_concurrent: int = 100) -> Dict:
    """Run load test with specified number of concurrent requests"""

    url = f"{base_url}/generate-story"
    test_data = {
        'character': 'Test Hero',
        'theme': 'Adventure',
        'character_age': 8,
        'learning_to_read_mode': False
    }

    print(f"🚀 Starting load test: {num_concurrent} concurrent requests to {url}")

    async with aiohttp.ClientSession() as session:
        # Create tasks for concurrent requests
        tasks = [make_request(session, url, test_data) for _ in range(num_concurrent)]

        # Execute all requests concurrently
        start_time = time.time()
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time

    # Analyze results
    successful_requests = [r for r in results if r['success']]
    failed_requests = [r for r in results if not r['success']]

    response_times = [r['response_time'] for r in results]

    analysis = {
        'total_requests': len(results),
        'successful_requests': len(successful_requests),
        'failed_requests': len(failed_requests),
        'success_rate': len(successful_requests) / len(results) * 100,
        'total_time': total_time,
        'requests_per_second': len(results) / total_time,
        'avg_response_time': statistics.mean(response_times),
        'median_response_time': statistics.median(response_times),
        'min_response_time': min(response_times),
        'max_response_time': max(response_times),
        '95th_percentile': statistics.quantiles(response_times, n=20)[18],  # 95th percentile
    }

    # Print results
    print("
📊 Load Test Results:"    print(f"Total Requests: {analysis['total_requests']}")
    print(f"Successful: {analysis['successful_requests']} ({analysis['success_rate']:.1f}%)")
    print(f"Failed: {analysis['failed_requests']}")
    print(f"Total Time: {analysis['total_time']:.2f}s")
    print(f"Requests/sec: {analysis['requests_per_second']:.1f}")
    print("
⏱️  Response Times:"    print(f"Average: {analysis['avg_response_time']:.3f}s")
    print(f"Median: {analysis['median_response_time']:.3f}s")
    print(f"Min: {analysis['min_response_time']:.3f}s")
    print(f"Max: {analysis['max_response_time']:.3f}s")
    print(f"95th Percentile: {analysis['95th_percentile']:.3f}s")

    if failed_requests:
        print("
❌ Sample Errors:"        for i, failure in enumerate(failed_requests[:5]):  # Show first 5 errors
            print(f"  {i+1}. Status: {failure['status']}, Error: {failure['error']}")

    return analysis

if __name__ == "__main__":
    # Test the API
    BASE_URL = "http://127.0.0.1:5000"

    # First check if server is running
    print("🔍 Checking if server is running...")
    try:
        import requests
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ Server is running")
        else:
            print(f"⚠️  Server responded with status {response.status_code}")
    except Exception as e:
        print(f"❌ Cannot connect to server: {e}")
        print("Please start the backend server first: cd backend && python run.py")
        exit(1)

    # Run the load test
    asyncio.run(load_test(BASE_URL, num_concurrent=100))