#!/usr/bin/env python3
"""
Network Simulation Test for Botany Battle
Tests multiplayer functionality under various network conditions
"""

import asyncio
import json
import logging
import time
import websockets
import random
import sys
import os
from typing import Dict, List, Optional, Tuple
import subprocess
import signal

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NetworkCondition:
    """Represents different network conditions for testing"""
    
    def __init__(self, name: str, latency_ms: int, packet_loss: float, bandwidth_kbps: int):
        self.name = name
        self.latency_ms = latency_ms
        self.packet_loss = packet_loss  # 0.0 to 1.0
        self.bandwidth_kbps = bandwidth_kbps

# Predefined network conditions
NETWORK_CONDITIONS = {
    "perfect": NetworkCondition("Perfect Network", 10, 0.0, 10000),
    "good_wifi": NetworkCondition("Good WiFi", 30, 0.001, 5000),
    "poor_wifi": NetworkCondition("Poor WiFi", 100, 0.02, 1000),
    "mobile_4g": NetworkCondition("Mobile 4G", 50, 0.005, 2000),
    "mobile_3g": NetworkCondition("Mobile 3G", 150, 0.01, 500),
    "poor_mobile": NetworkCondition("Poor Mobile", 300, 0.05, 100),
    "intermittent": NetworkCondition("Intermittent Connection", 200, 0.1, 500),
    "high_latency": NetworkCondition("High Latency", 500, 0.02, 1000),
}

class NetworkSimulator:
    """Simulates various network conditions using system-level tools"""
    
    def __init__(self):
        self.active_simulation = None
        self.tc_handle = None
        
    def apply_condition(self, condition: NetworkCondition, interface: str = "lo") -> bool:
        """Apply network condition using Linux tc (traffic control)"""
        try:
            # Note: This requires root privileges and Linux
            # For testing purposes, we'll simulate the effects at application level
            logger.info(f"Simulating network condition: {condition.name}")
            logger.info(f"  Latency: {condition.latency_ms}ms")
            logger.info(f"  Packet Loss: {condition.packet_loss*100:.1f}%")
            logger.info(f"  Bandwidth: {condition.bandwidth_kbps}kbps")
            
            self.active_simulation = condition
            return True
            
        except Exception as e:
            logger.error(f"Failed to apply network condition: {e}")
            return False
    
    def clear_conditions(self):
        """Clear all network conditions"""
        if self.active_simulation:
            logger.info(f"Clearing network simulation: {self.active_simulation.name}")
            self.active_simulation = None
    
    async def simulate_latency(self, base_delay: float = 0) -> float:
        """Simulate network latency"""
        if not self.active_simulation:
            return base_delay
            
        additional_delay = self.active_simulation.latency_ms / 1000.0
        jitter = random.uniform(-0.02, 0.02)  # ±20ms jitter
        
        total_delay = base_delay + additional_delay + jitter
        await asyncio.sleep(max(0, total_delay))
        return total_delay
    
    def should_drop_packet(self) -> bool:
        """Determine if packet should be dropped based on loss rate"""
        if not self.active_simulation:
            return False
        return random.random() < self.active_simulation.packet_loss

class NetworkAwarePlayer:
    """Player that works under simulated network conditions"""
    
    def __init__(self, player_id: str, simulator: NetworkSimulator):
        self.player_id = player_id
        self.simulator = simulator
        self.websocket = None
        self.connection_drops = 0
        self.message_timeouts = 0
        self.reconnections = 0
        
    async def connect(self, websocket_url: str, max_retries: int = 3) -> bool:
        """Connect with network simulation and retry logic"""
        for attempt in range(max_retries):
            try:
                await self.simulator.simulate_latency()
                
                if self.simulator.should_drop_packet():
                    raise ConnectionError("Simulated packet loss during connection")
                
                self.websocket = await websockets.connect(websocket_url)
                
                # Authenticate
                await self._send_message({
                    "type": "AUTHENTICATE",
                    "data": {
                        "playerId": self.player_id,
                        "username": f"NetworkTestPlayer_{self.player_id}",
                        "rating": random.randint(1000, 1500)
                    }
                })
                
                return True
                
            except Exception as e:
                logger.warning(f"Connection attempt {attempt + 1} failed: {e}")
                self.connection_drops += 1
                
                if attempt < max_retries - 1:
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
                    
        return False
    
    async def _send_message(self, message: dict) -> bool:
        """Send message with network simulation"""
        try:
            await self.simulator.simulate_latency()
            
            if self.simulator.should_drop_packet():
                logger.debug(f"Simulated packet drop for player {self.player_id}")
                return False
            
            if self.websocket and self.websocket.open:
                await self.websocket.send(json.dumps(message))
                return True
            else:
                raise ConnectionError("WebSocket not connected")
                
        except Exception as e:
            logger.error(f"Message send failed for player {self.player_id}: {e}")
            return False
    
    async def _receive_message(self, timeout: float = 5.0) -> Optional[dict]:
        """Receive message with timeout and network simulation"""
        try:
            await self.simulator.simulate_latency()
            
            if self.simulator.should_drop_packet():
                logger.debug(f"Simulated packet drop (receive) for player {self.player_id}")
                return None
            
            message = await asyncio.wait_for(self.websocket.recv(), timeout=timeout)
            return json.loads(message)
            
        except asyncio.TimeoutError:
            self.message_timeouts += 1
            logger.warning(f"Message timeout for player {self.player_id}")
            return None
        except Exception as e:
            logger.error(f"Message receive failed for player {self.player_id}: {e}")
            return None
    
    async def start_matchmaking(self) -> bool:
        """Start matchmaking with network resilience"""
        return await self._send_message({
            "type": "START_MATCHMAKING",
            "data": {"playerId": self.player_id}
        })
    
    async def submit_answer(self, game_id: str, round_num: int, answer: str) -> bool:
        """Submit answer with network simulation"""
        return await self._send_message({
            "type": "SUBMIT_ANSWER",
            "data": {
                "playerId": self.player_id,
                "gameId": game_id,
                "round": round_num,
                "answer": answer,
                "timestamp": time.time()
            }
        })
    
    async def wait_for_message_type(self, message_type: str, timeout: float = 30.0) -> Optional[dict]:
        """Wait for specific message type with network resilience"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            message = await self._receive_message(timeout=min(5.0, timeout - (time.time() - start_time)))
            
            if message and message.get("type") == message_type:
                return message
                
            if not message and self.websocket and not self.websocket.open:
                # Connection lost, attempt reconnection
                logger.info(f"Player {self.player_id} attempting reconnection...")
                if await self.reconnect():
                    self.reconnections += 1
                else:
                    break
                    
        return None
    
    async def reconnect(self) -> bool:
        """Attempt to reconnect after connection loss"""
        if self.websocket:
            await self.websocket.close()
            
        return await self.connect("ws://localhost:3001")
    
    async def disconnect(self):
        """Disconnect gracefully"""
        if self.websocket:
            await self.websocket.close()

class NetworkSimulationTester:
    def __init__(self, websocket_url: str = "ws://localhost:3001"):
        self.websocket_url = websocket_url
        self.simulator = NetworkSimulator()
    
    async def test_perfect_network_baseline(self) -> Dict:
        """Test baseline performance under perfect network conditions"""
        logger.info("Testing baseline performance (perfect network)...")
        
        self.simulator.apply_condition(NETWORK_CONDITIONS["perfect"])
        
        player1 = NetworkAwarePlayer("baseline-p1", self.simulator)
        player2 = NetworkAwarePlayer("baseline-p2", self.simulator)
        
        try:
            # Connect both players
            start_time = time.time()
            connected1 = await player1.connect(self.websocket_url)
            connected2 = await player2.connect(self.websocket_url)
            connection_time = time.time() - start_time
            
            if not (connected1 and connected2):
                return {"success": False, "error": "Failed to establish baseline connections"}
            
            # Start matchmaking
            mm_start = time.time()
            await player1.start_matchmaking()
            await player2.start_matchmaking()
            
            # Wait for match
            match1 = await player1.wait_for_message_type("MATCH_FOUND", timeout=30)
            match2 = await player2.wait_for_message_type("MATCH_FOUND", timeout=30)
            matchmaking_time = time.time() - mm_start
            
            if not (match1 and match2):
                return {"success": False, "error": "Matchmaking failed under perfect conditions"}
            
            return {
                "success": True,
                "connection_time": connection_time,
                "matchmaking_time": matchmaking_time,
                "connection_drops": player1.connection_drops + player2.connection_drops,
                "message_timeouts": player1.message_timeouts + player2.message_timeouts
            }
            
        finally:
            await player1.disconnect()
            await player2.disconnect()
            self.simulator.clear_conditions()
    
    async def test_poor_network_resilience(self) -> Dict:
        """Test system resilience under poor network conditions"""
        logger.info("Testing poor network resilience...")
        
        self.simulator.apply_condition(NETWORK_CONDITIONS["poor_mobile"])
        
        player1 = NetworkAwarePlayer("poor-p1", self.simulator)
        player2 = NetworkAwarePlayer("poor-p2", self.simulator)
        
        try:
            # Connect with retries
            start_time = time.time()
            connected1 = await player1.connect(self.websocket_url, max_retries=5)
            connected2 = await player2.connect(self.websocket_url, max_retries=5)
            connection_time = time.time() - start_time
            
            if not (connected1 and connected2):
                return {"success": False, "error": "Failed to connect under poor conditions"}
            
            # Attempt matchmaking with extended timeout
            mm_start = time.time()
            await player1.start_matchmaking()
            await player2.start_matchmaking()
            
            match1 = await player1.wait_for_message_type("MATCH_FOUND", timeout=60)
            match2 = await player2.wait_for_message_type("MATCH_FOUND", timeout=60)
            matchmaking_time = time.time() - mm_start
            
            success = match1 is not None and match2 is not None
            
            return {
                "success": success,
                "connection_time": connection_time,
                "matchmaking_time": matchmaking_time if success else None,
                "connection_drops": player1.connection_drops + player2.connection_drops,
                "message_timeouts": player1.message_timeouts + player2.message_timeouts,
                "reconnections": player1.reconnections + player2.reconnections
            }
            
        finally:
            await player1.disconnect()
            await player2.disconnect()
            self.simulator.clear_conditions()
    
    async def test_intermittent_connectivity(self) -> Dict:
        """Test handling of intermittent connectivity issues"""
        logger.info("Testing intermittent connectivity handling...")
        
        player1 = NetworkAwarePlayer("intermittent-p1", self.simulator)
        player2 = NetworkAwarePlayer("intermittent-p2", self.simulator)
        
        try:
            # Start with good connection
            self.simulator.apply_condition(NETWORK_CONDITIONS["good_wifi"])
            
            connected1 = await player1.connect(self.websocket_url)
            connected2 = await player2.connect(self.websocket_url)
            
            if not (connected1 and connected2):
                return {"success": False, "error": "Initial connection failed"}
            
            # Start matchmaking
            await player1.start_matchmaking()
            await player2.start_matchmaking()
            
            # Wait for match under good conditions
            match1 = await player1.wait_for_message_type("MATCH_FOUND", timeout=30)
            if not match1:
                return {"success": False, "error": "Failed to find match initially"}
            
            game_id = match1["data"]["gameId"]
            
            # Switch to intermittent connectivity during game
            self.simulator.apply_condition(NETWORK_CONDITIONS["intermittent"])
            
            # Play a round under poor conditions
            game_state = await player1.wait_for_message_type("GAME_STATE", timeout=30)
            if game_state:
                await player1.submit_answer(game_id, 1, "test_answer")
                await player2.submit_answer(game_id, 1, "test_answer")
                
                # Try to get round result
                result = await player1.wait_for_message_type("ROUND_RESULT", timeout=60)
                
                return {
                    "success": result is not None,
                    "game_continued": result is not None,
                    "connection_drops": player1.connection_drops + player2.connection_drops,
                    "message_timeouts": player1.message_timeouts + player2.message_timeouts,
                    "reconnections": player1.reconnections + player2.reconnections
                }
            else:
                return {"success": False, "error": "Failed to receive game state"}
                
        finally:
            await player1.disconnect()
            await player2.disconnect()
            self.simulator.clear_conditions()
    
    async def test_varying_network_conditions(self) -> Dict:
        """Test system behavior under varying network conditions"""
        logger.info("Testing varying network conditions...")
        
        condition_results = {}
        
        for condition_name, condition in NETWORK_CONDITIONS.items():
            logger.info(f"Testing condition: {condition_name}")
            
            self.simulator.apply_condition(condition)
            
            player1 = NetworkAwarePlayer(f"{condition_name}-p1", self.simulator)
            player2 = NetworkAwarePlayer(f"{condition_name}-p2", self.simulator)
            
            try:
                start_time = time.time()
                
                # Attempt connection with timeout based on condition
                timeout_multiplier = max(1, condition.latency_ms // 100)
                connection_timeout = 10 * timeout_multiplier
                
                connected1 = await asyncio.wait_for(
                    player1.connect(self.websocket_url), 
                    timeout=connection_timeout
                )
                connected2 = await asyncio.wait_for(
                    player2.connect(self.websocket_url),
                    timeout=connection_timeout
                )
                
                connection_time = time.time() - start_time
                
                if connected1 and connected2:
                    # Quick matchmaking test
                    await player1.start_matchmaking()
                    await player2.start_matchmaking()
                    
                    match_timeout = 30 * timeout_multiplier
                    match = await player1.wait_for_message_type("MATCH_FOUND", timeout=match_timeout)
                    
                    condition_results[condition_name] = {
                        "connection_success": True,
                        "connection_time": connection_time,
                        "matchmaking_success": match is not None,
                        "connection_drops": player1.connection_drops + player2.connection_drops,
                        "message_timeouts": player1.message_timeouts + player2.message_timeouts
                    }
                else:
                    condition_results[condition_name] = {
                        "connection_success": False,
                        "connection_time": connection_time,
                        "matchmaking_success": False,
                        "connection_drops": player1.connection_drops + player2.connection_drops,
                        "message_timeouts": player1.message_timeouts + player2.message_timeouts
                    }
                    
            except asyncio.TimeoutError:
                condition_results[condition_name] = {
                    "connection_success": False,
                    "connection_time": None,
                    "matchmaking_success": False,
                    "error": "Connection timeout"
                }
            finally:
                await player1.disconnect()
                await player2.disconnect()
        
        self.simulator.clear_conditions()
        
        # Analyze results
        successful_conditions = sum(1 for result in condition_results.values() if result.get("connection_success"))
        total_conditions = len(condition_results)
        
        return {
            "success": successful_conditions >= total_conditions * 0.7,  # 70% success rate
            "successful_conditions": successful_conditions,
            "total_conditions": total_conditions,
            "condition_results": condition_results
        }
    
    async def run_all_tests(self) -> Dict[str, Dict]:
        """Run all network simulation tests"""
        logger.info("🌐 Starting network simulation tests...")
        
        tests = [
            ("Perfect Network Baseline", self.test_perfect_network_baseline()),
            ("Poor Network Resilience", self.test_poor_network_resilience()),
            ("Intermittent Connectivity", self.test_intermittent_connectivity()),
            ("Varying Network Conditions", self.test_varying_network_conditions()),
        ]
        
        results = {}
        
        for test_name, test_coro in tests:
            logger.info(f"\n--- Running {test_name} ---")
            try:
                result = await test_coro
                results[test_name] = result
                status = "✅ PASSED" if result.get("success") else "❌ FAILED"
                logger.info(f"{test_name}: {status}")
            except Exception as e:
                logger.error(f"❌ {test_name} failed with exception: {e}")
                results[test_name] = {"success": False, "error": str(e)}
        
        return results
    
    def generate_report(self, results: Dict[str, Dict]) -> int:
        """Generate network simulation test report"""
        logger.info("\n" + "="*70)
        logger.info("🌐 Network Simulation Test Report")
        logger.info("="*70)
        
        overall_success = True
        
        for test_name, result in results.items():
            logger.info(f"\n{test_name}:")
            
            if not result.get("success"):
                logger.info(f"  ❌ FAILED")
                if "error" in result:
                    logger.info(f"  Error: {result['error']}")
                overall_success = False
            else:
                logger.info(f"  ✅ PASSED")
                
                # Additional metrics
                if "connection_time" in result:
                    logger.info(f"  Connection Time: {result['connection_time']:.2f}s")
                if "matchmaking_time" in result:
                    logger.info(f"  Matchmaking Time: {result['matchmaking_time']:.2f}s")
                if "connection_drops" in result:
                    logger.info(f"  Connection Drops: {result['connection_drops']}")
                if "reconnections" in result:
                    logger.info(f"  Reconnections: {result['reconnections']}")
                
                # Condition-specific results
                if "condition_results" in result:
                    logger.info(f"  Network Conditions Tested: {result['total_conditions']}")
                    logger.info(f"  Successful Conditions: {result['successful_conditions']}")
        
        logger.info("-" * 70)
        
        if overall_success:
            logger.info("🎉 All network simulation tests PASSED!")
            return 0
        else:
            logger.error("💥 Some network simulation tests FAILED!")
            return 1

async def main():
    """Main test runner"""
    websocket_url = os.getenv("WEBSOCKET_URL", "ws://localhost:3001")
    
    logger.info(f"Testing network resilience at: {websocket_url}")
    
    tester = NetworkSimulationTester(websocket_url)
    
    try:
        results = await tester.run_all_tests()
        exit_code = tester.generate_report(results)
        sys.exit(exit_code)
    except Exception as e:
        logger.error(f"Network simulation test runner failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())