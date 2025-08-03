#!/usr/bin/env python3
"""
Concurrent Users Load Test for Botany Battle
Tests system performance under high concurrent user load
"""

import asyncio
import json
import logging
import time
import websockets
from typing import Dict, List, Optional, Tuple
import sys
import os
import random
import statistics

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LoadTestPlayer:
    def __init__(self, player_id: str, player_index: int):
        self.player_id = player_id
        self.player_index = player_index
        self.websocket = None
        self.connected = False
        self.match_found = False
        self.connection_time = None
        self.match_time = None
        self.errors = []
        
    async def connect_and_play(self, websocket_url: str) -> Dict:
        """Connect to server and attempt to play"""
        start_time = time.time()
        
        try:
            # Connect
            self.websocket = await websockets.connect(websocket_url)
            self.connected = True
            self.connection_time = time.time() - start_time
            
            # Authenticate
            await self._authenticate()
            
            # Start matchmaking
            matchmaking_start = time.time()
            await self._start_matchmaking()
            
            # Wait for match (with timeout)
            match_found = await self._wait_for_match(timeout=60)
            if match_found:
                self.match_found = True
                self.match_time = time.time() - matchmaking_start
            
            # Keep connection alive for a bit
            await asyncio.sleep(random.uniform(5, 15))
            
            return {
                "success": True,
                "connection_time": self.connection_time,
                "match_time": self.match_time,
                "match_found": self.match_found,
                "errors": len(self.errors)
            }
            
        except Exception as e:
            self.errors.append(str(e))
            logger.error(f"Player {self.player_id} failed: {e}")
            return {
                "success": False,
                "connection_time": self.connection_time,
                "match_time": None,
                "match_found": False,
                "errors": len(self.errors),
                "error": str(e)
            }
        finally:
            await self._disconnect()
    
    async def _authenticate(self):
        """Send authentication message"""
        auth_message = {
            "type": "AUTHENTICATE",
            "data": {
                "playerId": self.player_id,
                "username": f"LoadTestPlayer{self.player_index}",
                "rating": random.randint(800, 1600)
            }
        }
        await self.websocket.send(json.dumps(auth_message))
    
    async def _start_matchmaking(self):
        """Start matchmaking"""
        matchmaking_message = {
            "type": "START_MATCHMAKING",
            "data": {
                "playerId": self.player_id,
                "preferredDifficulty": random.choice(["easy", "medium", "hard"])
            }
        }
        await self.websocket.send(json.dumps(matchmaking_message))
    
    async def _wait_for_match(self, timeout: int = 60) -> bool:
        """Wait for match to be found"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                message = await asyncio.wait_for(self.websocket.recv(), timeout=1.0)
                data = json.loads(message)
                
                if data.get("type") == "MATCH_FOUND":
                    return True
                elif data.get("type") == "MATCHMAKING_TIMEOUT":
                    return False
                    
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                self.errors.append(f"Match waiting error: {e}")
                continue
                
        return False
    
    async def _disconnect(self):
        """Disconnect from server"""
        if self.websocket:
            try:
                await self.websocket.close()
            except:
                pass

class ConcurrentUsersLoadTester:
    def __init__(self, websocket_url: str = "ws://localhost:3001"):
        self.websocket_url = websocket_url
        
    async def test_concurrent_connections(self, num_users: int = 50) -> Dict:
        """Test concurrent user connections"""
        logger.info(f"Testing {num_users} concurrent connections...")
        
        # Create players
        players = [LoadTestPlayer(f"load-user-{i}", i) for i in range(num_users)]
        
        # Start all connections simultaneously
        start_time = time.time()
        tasks = [player.connect_and_play(self.websocket_url) for player in players]
        
        # Wait for all to complete
        results = await asyncio.gather(*tasks, return_exceptions=True)
        total_time = time.time() - start_time
        
        # Analyze results
        successful_connections = sum(1 for result in results if isinstance(result, dict) and result.get("success"))
        failed_connections = num_users - successful_connections
        
        connection_times = [result["connection_time"] for result in results 
                          if isinstance(result, dict) and result.get("connection_time")]
        
        matches_found = sum(1 for result in results 
                           if isinstance(result, dict) and result.get("match_found"))
        
        match_times = [result["match_time"] for result in results 
                      if isinstance(result, dict) and result.get("match_time")]
        
        return {
            "total_users": num_users,
            "successful_connections": successful_connections,
            "failed_connections": failed_connections,
            "success_rate": successful_connections / num_users,
            "total_time": total_time,
            "avg_connection_time": statistics.mean(connection_times) if connection_times else 0,
            "max_connection_time": max(connection_times) if connection_times else 0,
            "matches_found": matches_found,
            "avg_match_time": statistics.mean(match_times) if match_times else 0,
            "connection_times": connection_times,
            "match_times": match_times
        }
    
    async def test_gradual_ramp_up(self, max_users: int = 100, ramp_duration: int = 60) -> Dict:
        """Test gradual user ramp-up"""
        logger.info(f"Testing gradual ramp-up to {max_users} users over {ramp_duration}s...")
        
        users_per_second = max_users / ramp_duration
        all_results = []
        active_tasks = []
        
        start_time = time.time()
        user_count = 0
        
        while time.time() - start_time < ramp_duration:
            # Add new users
            users_to_add = int((time.time() - start_time) * users_per_second) - user_count
            
            for i in range(users_to_add):
                player = LoadTestPlayer(f"ramp-user-{user_count}", user_count)
                task = asyncio.create_task(player.connect_and_play(self.websocket_url))
                active_tasks.append(task)
                user_count += 1
            
            await asyncio.sleep(1)
        
        # Wait for all tasks to complete
        logger.info(f"Waiting for {len(active_tasks)} tasks to complete...")
        results = await asyncio.gather(*active_tasks, return_exceptions=True)
        
        # Analyze results
        successful = sum(1 for result in results if isinstance(result, dict) and result.get("success"))
        
        return {
            "max_users": max_users,
            "actual_users_created": user_count,
            "successful_connections": successful,
            "success_rate": successful / user_count if user_count > 0 else 0,
            "ramp_duration": ramp_duration,
            "total_test_time": time.time() - start_time
        }
    
    async def test_burst_load(self, burst_size: int = 200, burst_interval: int = 5, num_bursts: int = 3) -> Dict:
        """Test handling of burst loads"""
        logger.info(f"Testing {num_bursts} bursts of {burst_size} users every {burst_interval}s...")
        
        all_results = []
        
        for burst_num in range(num_bursts):
            logger.info(f"Starting burst {burst_num + 1}/{num_bursts}")
            
            # Create burst of users
            players = [LoadTestPlayer(f"burst-{burst_num}-user-{i}", i) for i in range(burst_size)]
            
            # Start all simultaneously
            start_time = time.time()
            tasks = [player.connect_and_play(self.websocket_url) for player in players]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            burst_time = time.time() - start_time
            
            successful = sum(1 for result in results if isinstance(result, dict) and result.get("success"))
            
            burst_result = {
                "burst_number": burst_num + 1,
                "burst_size": burst_size,
                "successful": successful,
                "success_rate": successful / burst_size,
                "burst_time": burst_time
            }
            
            all_results.append(burst_result)
            logger.info(f"Burst {burst_num + 1} completed: {successful}/{burst_size} successful")
            
            # Wait before next burst
            if burst_num < num_bursts - 1:
                await asyncio.sleep(burst_interval)
        
        # Calculate overall stats
        total_users = num_bursts * burst_size
        total_successful = sum(result["successful"] for result in all_results)
        
        return {
            "num_bursts": num_bursts,
            "burst_size": burst_size,
            "burst_interval": burst_interval,
            "total_users": total_users,
            "total_successful": total_successful,
            "overall_success_rate": total_successful / total_users,
            "burst_results": all_results
        }
    
    async def test_sustained_load(self, concurrent_users: int = 100, duration_minutes: int = 5) -> Dict:
        """Test sustained load over time"""
        logger.info(f"Testing sustained load: {concurrent_users} users for {duration_minutes} minutes...")
        
        duration_seconds = duration_minutes * 60
        user_sessions = []
        active_tasks = []
        
        # Function to create a user session
        async def user_session(user_id: str):
            session_results = []
            session_start = time.time()
            
            while time.time() - session_start < duration_seconds:
                player = LoadTestPlayer(f"sustained-{user_id}-{len(session_results)}", len(session_results))
                
                try:
                    result = await player.connect_and_play(self.websocket_url)
                    session_results.append(result)
                except Exception as e:
                    session_results.append({"success": False, "error": str(e)})
                
                # Wait before next session
                await asyncio.sleep(random.uniform(10, 30))
            
            return session_results
        
        # Start user sessions
        for i in range(concurrent_users):
            task = asyncio.create_task(user_session(str(i)))
            active_tasks.append(task)
        
        # Wait for test duration
        all_session_results = await asyncio.gather(*active_tasks, return_exceptions=True)
        
        # Analyze results
        total_sessions = sum(len(sessions) for sessions in all_session_results if isinstance(sessions, list))
        successful_sessions = sum(
            sum(1 for session in sessions if session.get("success"))
            for sessions in all_session_results if isinstance(sessions, list)
        )
        
        return {
            "concurrent_users": concurrent_users,
            "duration_minutes": duration_minutes,
            "total_sessions": total_sessions,
            "successful_sessions": successful_sessions,
            "success_rate": successful_sessions / total_sessions if total_sessions > 0 else 0,
            "sessions_per_user": total_sessions / concurrent_users if concurrent_users > 0 else 0
        }
    
    async def run_all_tests(self) -> Dict[str, Dict]:
        """Run all concurrent user load tests"""
        logger.info("🚀 Starting concurrent users load tests...")
        
        tests = [
            ("50 Concurrent Connections", self.test_concurrent_connections(50)),
            ("100 Concurrent Connections", self.test_concurrent_connections(100)),
            ("Gradual Ramp-up", self.test_gradual_ramp_up(100, 30)),
            ("Burst Load", self.test_burst_load(50, 10, 3)),
            ("Sustained Load", self.test_sustained_load(20, 2)),  # Reduced for CI
        ]
        
        results = {}
        
        for test_name, test_coro in tests:
            logger.info(f"\n--- Running {test_name} ---")
            try:
                result = await test_coro
                results[test_name] = result
                logger.info(f"✅ {test_name} completed")
            except Exception as e:
                logger.error(f"❌ {test_name} failed: {e}")
                results[test_name] = {"success": False, "error": str(e)}
        
        return results
    
    def generate_report(self, results: Dict[str, Dict]) -> int:
        """Generate load test report"""
        logger.info("\n" + "="*70)
        logger.info("🚀 Concurrent Users Load Test Report")
        logger.info("="*70)
        
        overall_success = True
        
        for test_name, result in results.items():
            logger.info(f"\n{test_name}:")
            
            if result.get("success") is False:
                logger.info(f"  ❌ FAILED: {result.get('error', 'Unknown error')}")
                overall_success = False
                continue
            
            if "success_rate" in result:
                success_rate = result["success_rate"] * 100
                status = "✅ PASSED" if success_rate >= 80 else "❌ FAILED"
                logger.info(f"  {status} - Success Rate: {success_rate:.1f}%")
                
                if success_rate < 80:
                    overall_success = False
            
            # Additional metrics based on test type
            if "concurrent_connections" in test_name.lower():
                logger.info(f"  Successful Connections: {result.get('successful_connections', 0)}")
                logger.info(f"  Average Connection Time: {result.get('avg_connection_time', 0):.3f}s")
                logger.info(f"  Matches Found: {result.get('matches_found', 0)}")
                
            elif "ramp-up" in test_name.lower():
                logger.info(f"  Users Created: {result.get('actual_users_created', 0)}")
                logger.info(f"  Test Duration: {result.get('total_test_time', 0):.1f}s")
                
            elif "burst" in test_name.lower():
                logger.info(f"  Total Users: {result.get('total_users', 0)}")
                logger.info(f"  Bursts Completed: {result.get('num_bursts', 0)}")
                
            elif "sustained" in test_name.lower():
                logger.info(f"  Total Sessions: {result.get('total_sessions', 0)}")
                logger.info(f"  Sessions per User: {result.get('sessions_per_user', 0):.1f}")
        
        logger.info("-" * 70)
        
        if overall_success:
            logger.info("🎉 All concurrent users load tests PASSED!")
            return 0
        else:
            logger.error("💥 Some concurrent users load tests FAILED!")
            return 1

async def main():
    """Main test runner"""
    websocket_url = os.getenv("WEBSOCKET_URL", "ws://localhost:3001")
    
    logger.info(f"Testing concurrent users load at: {websocket_url}")
    
    tester = ConcurrentUsersLoadTester(websocket_url)
    
    try:
        results = await tester.run_all_tests()
        exit_code = tester.generate_report(results)
        sys.exit(exit_code)
    except Exception as e:
        logger.error(f"Load test runner failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())