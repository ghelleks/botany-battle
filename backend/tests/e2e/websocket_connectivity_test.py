#!/usr/bin/env python3
"""
WebSocket Connectivity Test for Botany Battle
Tests basic WebSocket connection, message exchange, and error handling
"""

import asyncio
import json
import logging
import time
import websockets
from typing import Dict, List, Optional
import sys
import os

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class WebSocketConnectivityTester:
    def __init__(self, websocket_url: str = "ws://localhost:3001"):
        self.websocket_url = websocket_url
        self.test_results = []
        
    async def test_basic_connection(self) -> bool:
        """Test basic WebSocket connection establishment"""
        try:
            logger.info("Testing basic WebSocket connection...")
            async with websockets.connect(self.websocket_url) as websocket:
                logger.info("✅ WebSocket connection established successfully")
                return True
        except Exception as e:
            logger.error(f"❌ Failed to establish WebSocket connection: {e}")
            return False
    
    async def test_message_echo(self) -> bool:
        """Test sending and receiving messages"""
        try:
            logger.info("Testing message echo...")
            async with websockets.connect(self.websocket_url) as websocket:
                test_message = {
                    "type": "TEST_ECHO",
                    "data": {"message": "Hello WebSocket", "timestamp": time.time()}
                }
                
                await websocket.send(json.dumps(test_message))
                
                # Wait for response
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                response_data = json.loads(response)
                
                if response_data.get("type") == "ECHO_RESPONSE":
                    logger.info("✅ Message echo test passed")
                    return True
                else:
                    logger.error(f"❌ Unexpected response: {response_data}")
                    return False
                    
        except asyncio.TimeoutError:
            logger.error("❌ Message echo test timed out")
            return False
        except Exception as e:
            logger.error(f"❌ Message echo test failed: {e}")
            return False
    
    async def test_concurrent_connections(self, num_connections: int = 10) -> bool:
        """Test multiple concurrent WebSocket connections"""
        logger.info(f"Testing {num_connections} concurrent connections...")
        
        async def create_connection():
            try:
                async with websockets.connect(self.websocket_url) as websocket:
                    await websocket.send(json.dumps({"type": "PING"}))
                    await websocket.recv()
                    return True
            except Exception as e:
                logger.error(f"Concurrent connection failed: {e}")
                return False
        
        tasks = [create_connection() for _ in range(num_connections)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        successful_connections = sum(1 for result in results if result is True)
        success_rate = successful_connections / num_connections
        
        if success_rate >= 0.9:  # 90% success rate
            logger.info(f"✅ Concurrent connections test passed: {successful_connections}/{num_connections}")
            return True
        else:
            logger.error(f"❌ Concurrent connections test failed: {successful_connections}/{num_connections}")
            return False
    
    async def test_message_throughput(self, message_count: int = 100) -> bool:
        """Test high-volume message handling"""
        logger.info(f"Testing message throughput with {message_count} messages...")
        
        try:
            async with websockets.connect(self.websocket_url) as websocket:
                start_time = time.time()
                
                # Send messages rapidly
                for i in range(message_count):
                    message = {
                        "type": "THROUGHPUT_TEST",
                        "data": {"messageId": i, "timestamp": time.time()}
                    }
                    await websocket.send(json.dumps(message))
                
                # Wait for acknowledgment
                ack_count = 0
                while ack_count < message_count:
                    try:
                        response = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                        response_data = json.loads(response)
                        if response_data.get("type") == "THROUGHPUT_ACK":
                            ack_count += 1
                    except asyncio.TimeoutError:
                        break
                
                end_time = time.time()
                duration = end_time - start_time
                throughput = message_count / duration
                
                logger.info(f"Sent {message_count} messages in {duration:.2f}s")
                logger.info(f"Throughput: {throughput:.2f} messages/second")
                logger.info(f"Acknowledged: {ack_count}/{message_count}")
                
                if ack_count >= message_count * 0.95:  # 95% acknowledgment rate
                    logger.info("✅ Message throughput test passed")
                    return True
                else:
                    logger.error("❌ Message throughput test failed")
                    return False
                    
        except Exception as e:
            logger.error(f"❌ Message throughput test failed: {e}")
            return False
    
    async def test_connection_recovery(self) -> bool:
        """Test connection recovery after disconnection"""
        logger.info("Testing connection recovery...")
        
        try:
            # Initial connection
            async with websockets.connect(self.websocket_url) as websocket:
                logger.info("Initial connection established")
                
                # Send a message to ensure connection is working
                await websocket.send(json.dumps({"type": "PING"}))
                await websocket.recv()
                
                # Force disconnection by closing socket
                await websocket.close()
                logger.info("Connection closed")
            
            # Attempt reconnection
            await asyncio.sleep(2)  # Wait a bit before reconnecting
            
            async with websockets.connect(self.websocket_url) as websocket:
                logger.info("Reconnection established")
                
                # Test that reconnection is working
                await websocket.send(json.dumps({"type": "PING"}))
                await websocket.recv()
                
                logger.info("✅ Connection recovery test passed")
                return True
                
        except Exception as e:
            logger.error(f"❌ Connection recovery test failed: {e}")
            return False
    
    async def test_malformed_message_handling(self) -> bool:
        """Test server handling of malformed messages"""
        logger.info("Testing malformed message handling...")
        
        try:
            async with websockets.connect(self.websocket_url) as websocket:
                # Send malformed JSON
                await websocket.send("invalid json {{{")
                
                # Server should not crash and should send error response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    response_data = json.loads(response)
                    
                    if response_data.get("type") == "ERROR":
                        logger.info("✅ Malformed message handling test passed")
                        return True
                    else:
                        logger.error(f"❌ Expected ERROR response, got: {response_data}")
                        return False
                        
                except asyncio.TimeoutError:
                    logger.info("✅ Server handled malformed message gracefully (no response)")
                    return True
                    
        except Exception as e:
            logger.error(f"❌ Malformed message handling test failed: {e}")
            return False
    
    async def test_large_message_handling(self) -> bool:
        """Test handling of large messages"""
        logger.info("Testing large message handling...")
        
        try:
            async with websockets.connect(self.websocket_url) as websocket:
                # Create a large message (10KB)
                large_data = "x" * 10000
                message = {
                    "type": "LARGE_MESSAGE_TEST",
                    "data": {"content": large_data}
                }
                
                await websocket.send(json.dumps(message))
                
                # Wait for response
                response = await asyncio.wait_for(websocket.recv(), timeout=10.0)
                response_data = json.loads(response)
                
                if response_data.get("type") in ["LARGE_MESSAGE_ACK", "ERROR"]:
                    logger.info("✅ Large message handling test passed")
                    return True
                else:
                    logger.error(f"❌ Unexpected response to large message: {response_data}")
                    return False
                    
        except Exception as e:
            logger.error(f"❌ Large message handling test failed: {e}")
            return False
    
    async def run_all_tests(self) -> Dict[str, bool]:
        """Run all WebSocket connectivity tests"""
        logger.info("🧪 Starting WebSocket connectivity tests...")
        
        tests = [
            ("Basic Connection", self.test_basic_connection()),
            ("Message Echo", self.test_message_echo()),
            ("Concurrent Connections", self.test_concurrent_connections(10)),
            ("Message Throughput", self.test_message_throughput(100)),
            ("Connection Recovery", self.test_connection_recovery()),
            ("Malformed Message Handling", self.test_malformed_message_handling()),
            ("Large Message Handling", self.test_large_message_handling()),
        ]
        
        results = {}
        
        for test_name, test_coro in tests:
            logger.info(f"\n--- Running {test_name} ---")
            try:
                result = await test_coro
                results[test_name] = result
            except Exception as e:
                logger.error(f"Test {test_name} threw exception: {e}")
                results[test_name] = False
        
        return results
    
    def generate_report(self, results: Dict[str, bool]) -> None:
        """Generate test report"""
        logger.info("\n" + "="*50)
        logger.info("🔍 WebSocket Connectivity Test Report")
        logger.info("="*50)
        
        passed_tests = sum(1 for result in results.values() if result)
        total_tests = len(results)
        success_rate = (passed_tests / total_tests) * 100
        
        for test_name, result in results.items():
            status = "✅ PASSED" if result else "❌ FAILED"
            logger.info(f"{test_name}: {status}")
        
        logger.info("-" * 50)
        logger.info(f"Total: {passed_tests}/{total_tests} tests passed ({success_rate:.1f}%)")
        
        if success_rate >= 90:
            logger.info("🎉 WebSocket connectivity tests PASSED!")
            return 0
        else:
            logger.error("💥 WebSocket connectivity tests FAILED!")
            return 1

async def main():
    """Main test runner"""
    websocket_url = os.getenv("WEBSOCKET_URL", "ws://localhost:3001")
    
    logger.info(f"Testing WebSocket server at: {websocket_url}")
    
    tester = WebSocketConnectivityTester(websocket_url)
    
    try:
        results = await tester.run_all_tests()
        exit_code = tester.generate_report(results)
        sys.exit(exit_code)
    except Exception as e:
        logger.error(f"Test runner failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())