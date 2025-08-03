#!/usr/bin/env python3
"""
Matchmaking Stress Test for Botany Battle
Tests matchmaking system under various stress conditions
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

class MatchmakingTestPlayer:
    def __init__(self, player_id: str, rating: int, region: str = "US"):
        self.player_id = player_id
        self.rating = rating
        self.region = region
        self.websocket = None
        self.queue_entry_time = None
        self.match_found_time = None
        self.matched_opponent = None
        self.match_found = False
        
    async def connect_and_queue(self, websocket_url: str) -> Dict:
        """Connect and enter matchmaking queue"""
        try:
            self.websocket = await websockets.connect(websocket_url)
            
            # Authenticate
            await self._authenticate()
            
            # Enter matchmaking queue
            self.queue_entry_time = time.time()
            await self._enter_queue()
            
            # Wait for match
            match_result = await self._wait_for_match(timeout=120)  # 2 minute timeout
            
            return match_result
            
        except Exception as e:
            logger.error(f"Player {self.player_id} failed: {e}")
            return {
                "success": False,
                "player_id": self.player_id,
                "rating": self.rating,
                "error": str(e)
            }
        finally:
            await self._disconnect()
    
    async def _authenticate(self):
        """Authenticate with server"""
        auth_message = {
            "type": "AUTHENTICATE",
            "data": {
                "playerId": self.player_id,
                "username": f"MMTestPlayer_{self.player_id}",
                "rating": self.rating,
                "region": self.region
            }
        }
        await self.websocket.send(json.dumps(auth_message))
    
    async def _enter_queue(self):
        """Enter matchmaking queue"""
        queue_message = {
            "type": "START_MATCHMAKING",
            "data": {
                "playerId": self.player_id,
                "preferredDifficulty": "medium"
            }
        }
        await self.websocket.send(json.dumps(queue_message))
    
    async def _wait_for_match(self, timeout: int = 120) -> Dict:
        """Wait for match to be found"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                message = await asyncio.wait_for(self.websocket.recv(), timeout=1.0)
                data = json.loads(message)
                
                if data.get("type") == "MATCH_FOUND":
                    self.match_found_time = time.time()
                    self.match_found = True
                    self.matched_opponent = data["data"]["opponent"]
                    
                    wait_time = self.match_found_time - self.queue_entry_time
                    rating_difference = abs(self.rating - self.matched_opponent.get("rating", 0))
                    
                    return {
                        "success": True,
                        "player_id": self.player_id,
                        "rating": self.rating,
                        "opponent_id": self.matched_opponent.get("id"),
                        "opponent_rating": self.matched_opponent.get("rating"),
                        "rating_difference": rating_difference,
                        "wait_time": wait_time,
                        "match_found": True
                    }
                
                elif data.get("type") == "MATCHMAKING_TIMEOUT":
                    return {
                        "success": True,
                        "player_id": self.player_id,
                        "rating": self.rating,
                        "wait_time": time.time() - self.queue_entry_time,
                        "match_found": False,
                        "timeout": True
                    }
                    
                elif data.get("type") == "QUEUE_UPDATE":
                    # Log queue position updates
                    position = data["data"].get("position", "unknown")
                    estimated_wait = data["data"].get("estimatedWaitTime", "unknown")
                    logger.debug(f"Player {self.player_id} queue position: {position}, estimated wait: {estimated_wait}")
                    
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                logger.error(f"Error waiting for match for player {self.player_id}: {e}")
                continue
        
        # Timeout reached
        return {
            "success": True,
            "player_id": self.player_id,
            "rating": self.rating,
            "wait_time": timeout,
            "match_found": False,
            "timeout": True
        }
    
    async def _disconnect(self):
        """Disconnect from server"""
        if self.websocket:
            try:
                await self.websocket.close()
            except:
                pass

class MatchmakingStressTester:
    def __init__(self, websocket_url: str = "ws://localhost:3001"):
        self.websocket_url = websocket_url
    
    def create_rating_distribution(self, num_players: int) -> List[int]:
        """Create realistic rating distribution"""
        ratings = []
        
        # 20% beginners (800-1000)
        beginners = int(num_players * 0.2)
        ratings.extend([random.randint(800, 1000) for _ in range(beginners)])
        
        # 60% intermediate (1000-1400) 
        intermediate = int(num_players * 0.6)
        ratings.extend([random.randint(1000, 1400) for _ in range(intermediate)])
        
        # 15% advanced (1400-1600)
        advanced = int(num_players * 0.15)
        ratings.extend([random.randint(1400, 1600) for _ in range(advanced)])
        
        # 5% expert (1600-1800)
        expert = num_players - (beginners + intermediate + advanced)
        ratings.extend([random.randint(1600, 1800) for _ in range(expert)])
        
        random.shuffle(ratings)
        return ratings
    
    async def test_basic_matchmaking_accuracy(self, num_players: int = 50) -> Dict:
        """Test basic matchmaking with skill-based matching"""
        logger.info(f"Testing matchmaking accuracy with {num_players} players...")
        
        ratings = self.create_rating_distribution(num_players)
        players = [
            MatchmakingTestPlayer(f"accuracy-player-{i}", ratings[i])
            for i in range(num_players)
        ]
        
        # Start all players
        start_time = time.time()
        tasks = [player.connect_and_queue(self.websocket_url) for player in players]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        total_time = time.time() - start_time
        
        # Analyze results
        successful_matches = [r for r in results if isinstance(r, dict) and r.get("match_found")]
        timeouts = [r for r in results if isinstance(r, dict) and r.get("timeout")]
        errors = [r for r in results if isinstance(r, dict) and not r.get("success")]
        
        # Calculate rating accuracy
        rating_differences = [r["rating_difference"] for r in successful_matches if "rating_difference" in r]
        avg_rating_diff = statistics.mean(rating_differences) if rating_differences else 0
        max_rating_diff = max(rating_differences) if rating_differences else 0
        
        # Calculate wait times
        wait_times = [r["wait_time"] for r in successful_matches + timeouts if "wait_time" in r]
        avg_wait_time = statistics.mean(wait_times) if wait_times else 0
        
        return {
            "num_players": num_players,
            "successful_matches": len(successful_matches),
            "timeouts": len(timeouts),
            "errors": len(errors),
            "match_rate": len(successful_matches) / num_players,
            "avg_rating_difference": avg_rating_diff,
            "max_rating_difference": max_rating_diff,
            "avg_wait_time": avg_wait_time,
            "total_test_time": total_time
        }
    
    async def test_queue_management_under_load(self, num_players: int = 200) -> Dict:
        """Test queue management with large number of players"""
        logger.info(f"Testing queue management under load with {num_players} players...")
        
        ratings = self.create_rating_distribution(num_players)
        
        # Add players to queue in waves
        wave_size = 50
        waves = [ratings[i:i + wave_size] for i in range(0, len(ratings), wave_size)]
        
        all_results = []
        
        for wave_num, wave_ratings in enumerate(waves):
            logger.info(f"Starting wave {wave_num + 1}/{len(waves)} with {len(wave_ratings)} players")
            
            players = [
                MatchmakingTestPlayer(f"load-w{wave_num}-p{i}", rating)
                for i, rating in enumerate(wave_ratings)
            ]
            
            # Start wave
            tasks = [player.connect_and_queue(self.websocket_url) for player in players]
            wave_results = await asyncio.gather(*tasks, return_exceptions=True)
            all_results.extend(wave_results)
            
            # Small delay between waves
            await asyncio.sleep(2)
        
        # Analyze all results
        successful_matches = [r for r in all_results if isinstance(r, dict) and r.get("match_found")]
        total_valid_results = [r for r in all_results if isinstance(r, dict) and r.get("success")]
        
        queue_efficiency = len(successful_matches) / len(total_valid_results) if total_valid_results else 0
        
        return {
            "num_players": num_players,
            "num_waves": len(waves),
            "wave_size": wave_size,
            "successful_matches": len(successful_matches),
            "total_valid_results": len(total_valid_results),
            "queue_efficiency": queue_efficiency
        }
    
    async def test_rating_range_matching(self) -> Dict:
        """Test that players are matched within appropriate rating ranges"""
        logger.info("Testing rating range matching...")
        
        # Create specific rating scenarios
        test_scenarios = [
            # Scenario 1: Tight skill range
            ([1200, 1205, 1210, 1215, 1220, 1225], "tight_range"),
            
            # Scenario 2: Wide skill range  
            ([800, 1000, 1200, 1400, 1600, 1800], "wide_range"),
            
            # Scenario 3: Outliers
            ([1200, 1200, 1200, 1200, 800, 1800], "outliers"),
        ]
        
        scenario_results = {}
        
        for ratings, scenario_name in test_scenarios:
            logger.info(f"Testing scenario: {scenario_name}")
            
            players = [
                MatchmakingTestPlayer(f"{scenario_name}-player-{i}", rating)
                for i, rating in enumerate(ratings)
            ]
            
            tasks = [player.connect_and_queue(self.websocket_url) for player in players]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            matches = [r for r in results if isinstance(r, dict) and r.get("match_found")]
            rating_diffs = [r["rating_difference"] for r in matches if "rating_difference" in r]
            
            scenario_results[scenario_name] = {
                "matches_found": len(matches),
                "avg_rating_diff": statistics.mean(rating_diffs) if rating_diffs else 0,
                "max_rating_diff": max(rating_diffs) if rating_diffs else 0,
                "rating_diffs": rating_diffs
            }
        
        return scenario_results
    
    async def test_queue_fairness(self, num_players: int = 100) -> Dict:
        """Test that matchmaking is fair and doesn't favor certain ratings"""
        logger.info(f"Testing queue fairness with {num_players} players...")
        
        # Create players with even distribution across rating ranges
        rating_buckets = {
            "low": list(range(800, 1000, 20)),
            "medium": list(range(1000, 1400, 20)), 
            "high": list(range(1400, 1800, 20))
        }
        
        players = []
        player_id = 0
        
        # Distribute players evenly across buckets
        players_per_bucket = num_players // 3
        
        for bucket_name, bucket_ratings in rating_buckets.items():
            for i in range(players_per_bucket):
                rating = random.choice(bucket_ratings)
                players.append(MatchmakingTestPlayer(f"fair-{bucket_name}-{i}", rating))
                player_id += 1
        
        # Add remaining players to medium bucket
        remaining = num_players - len(players)
        for i in range(remaining):
            rating = random.choice(rating_buckets["medium"])
            players.append(MatchmakingTestPlayer(f"fair-medium-extra-{i}", rating))
        
        # Run matchmaking
        tasks = [player.connect_and_queue(self.websocket_url) for player in players]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Analyze fairness by rating bucket
        bucket_analysis = {}
        
        for bucket_name, bucket_ratings in rating_buckets.items():
            bucket_results = [
                r for r in results 
                if isinstance(r, dict) and r.get("rating") in bucket_ratings
            ]
            
            matches = [r for r in bucket_results if r.get("match_found")]
            match_rate = len(matches) / len(bucket_results) if bucket_results else 0
            
            avg_wait_time = statistics.mean([r["wait_time"] for r in matches]) if matches else 0
            
            bucket_analysis[bucket_name] = {
                "total_players": len(bucket_results),
                "matches_found": len(matches),
                "match_rate": match_rate,
                "avg_wait_time": avg_wait_time
            }
        
        return bucket_analysis
    
    async def test_rapid_queue_churn(self, iterations: int = 10) -> Dict:
        """Test rapid players joining and leaving queues"""
        logger.info(f"Testing rapid queue churn over {iterations} iterations...")
        
        churn_results = []
        
        for iteration in range(iterations):
            logger.info(f"Churn iteration {iteration + 1}/{iterations}")
            
            # Create players
            num_players = random.randint(20, 50)
            ratings = self.create_rating_distribution(num_players)
            
            players = [
                MatchmakingTestPlayer(f"churn-{iteration}-{i}", ratings[i])
                for i in range(num_players)
            ]
            
            # Some players will queue normally, others will cancel early
            normal_players = players[:len(players)//2]
            quick_exit_players = players[len(players)//2:]
            
            # Start all players
            all_tasks = []
            
            # Normal players
            for player in normal_players:
                task = asyncio.create_task(player.connect_and_queue(self.websocket_url))
                all_tasks.append(("normal", task))
            
            # Quick exit players (will disconnect after short time)
            async def quick_exit_session(player):
                try:
                    await player.connect_and_queue(self.websocket_url)
                except:
                    pass
                
                # Disconnect quickly
                await asyncio.sleep(random.uniform(1, 5))
                await player._disconnect()
                
                return {"player_id": player.player_id, "type": "quick_exit"}
            
            for player in quick_exit_players:
                task = asyncio.create_task(quick_exit_session(player))
                all_tasks.append(("quick_exit", task))
            
            # Wait for completion
            iteration_start = time.time()
            results = await asyncio.gather(*[task for _, task in all_tasks], return_exceptions=True)
            iteration_time = time.time() - iteration_start
            
            # Analyze iteration
            normal_results = results[:len(normal_players)]
            successful_matches = sum(1 for r in normal_results if isinstance(r, dict) and r.get("match_found"))
            
            churn_results.append({
                "iteration": iteration + 1,
                "total_players": num_players,
                "normal_players": len(normal_players),
                "quick_exit_players": len(quick_exit_players),
                "successful_matches": successful_matches,
                "iteration_time": iteration_time
            })
        
        # Overall analysis
        avg_match_rate = statistics.mean([
            r["successful_matches"] / r["normal_players"] if r["normal_players"] > 0 else 0
            for r in churn_results
        ])
        
        return {
            "iterations": iterations,
            "avg_match_rate": avg_match_rate,
            "iteration_results": churn_results
        }
    
    async def run_all_tests(self) -> Dict[str, Dict]:
        """Run all matchmaking stress tests"""
        logger.info("⚔️  Starting matchmaking stress tests...")
        
        tests = [
            ("Basic Matchmaking Accuracy", self.test_basic_matchmaking_accuracy(50)),
            ("Queue Management Under Load", self.test_queue_management_under_load(100)),
            ("Rating Range Matching", self.test_rating_range_matching()),
            ("Queue Fairness", self.test_queue_fairness(60)),
            ("Rapid Queue Churn", self.test_rapid_queue_churn(5)),
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
        """Generate matchmaking stress test report"""
        logger.info("\n" + "="*70)
        logger.info("⚔️  Matchmaking Stress Test Report")
        logger.info("="*70)
        
        overall_success = True
        
        for test_name, result in results.items():
            logger.info(f"\n{test_name}:")
            
            if result.get("success") is False:
                logger.info(f"  ❌ FAILED: {result.get('error', 'Unknown error')}")
                overall_success = False
                continue
            
            # Basic Matchmaking Accuracy
            if "accuracy" in test_name.lower():
                match_rate = result.get("match_rate", 0) * 100
                avg_rating_diff = result.get("avg_rating_difference", 0)
                avg_wait_time = result.get("avg_wait_time", 0)
                
                status = "✅ PASSED" if match_rate >= 60 and avg_rating_diff <= 200 else "❌ FAILED"
                logger.info(f"  {status}")
                logger.info(f"  Match Rate: {match_rate:.1f}%")
                logger.info(f"  Avg Rating Difference: {avg_rating_diff:.0f}")
                logger.info(f"  Avg Wait Time: {avg_wait_time:.1f}s")
                
                if match_rate < 60 or avg_rating_diff > 200:
                    overall_success = False
            
            # Queue Management
            elif "queue management" in test_name.lower():
                efficiency = result.get("queue_efficiency", 0) * 100
                status = "✅ PASSED" if efficiency >= 50 else "❌ FAILED"
                logger.info(f"  {status} - Queue Efficiency: {efficiency:.1f}%")
                
                if efficiency < 50:
                    overall_success = False
            
            # Rating Range Matching
            elif "rating range" in test_name.lower():
                all_good = True
                for scenario, data in result.items():
                    avg_diff = data.get("avg_rating_diff", 0)
                    max_diff = data.get("max_rating_diff", 0)
                    
                    if max_diff > 400:  # Max 400 rating difference allowed
                        all_good = False
                    
                    logger.info(f"  {scenario}: avg_diff={avg_diff:.0f}, max_diff={max_diff:.0f}")
                
                status = "✅ PASSED" if all_good else "❌ FAILED"
                logger.info(f"  {status}")
                
                if not all_good:
                    overall_success = False
            
            # Queue Fairness
            elif "fairness" in test_name.lower():
                match_rates = [data.get("match_rate", 0) for data in result.values()]
                fairness_variance = statistics.stdev(match_rates) if len(match_rates) > 1 else 0
                
                status = "✅ PASSED" if fairness_variance < 0.2 else "❌ FAILED"
                logger.info(f"  {status} - Fairness Variance: {fairness_variance:.3f}")
                
                for bucket, data in result.items():
                    logger.info(f"  {bucket}: {data['match_rate']*100:.1f}% match rate")
                
                if fairness_variance >= 0.2:
                    overall_success = False
            
            # Rapid Queue Churn
            elif "churn" in test_name.lower():
                avg_match_rate = result.get("avg_match_rate", 0) * 100
                status = "✅ PASSED" if avg_match_rate >= 40 else "❌ FAILED"
                logger.info(f"  {status} - Avg Match Rate: {avg_match_rate:.1f}%")
                logger.info(f"  Iterations: {result.get('iterations', 0)}")
                
                if avg_match_rate < 40:
                    overall_success = False
        
        logger.info("-" * 70)
        
        if overall_success:
            logger.info("🎉 All matchmaking stress tests PASSED!")
            return 0
        else:
            logger.error("💥 Some matchmaking stress tests FAILED!")
            return 1

async def main():
    """Main test runner"""
    websocket_url = os.getenv("WEBSOCKET_URL", "ws://localhost:3001")
    
    logger.info(f"Testing matchmaking stress at: {websocket_url}")
    
    tester = MatchmakingStressTester(websocket_url)
    
    try:
        results = await tester.run_all_tests()
        exit_code = tester.generate_report(results)
        sys.exit(exit_code)
    except Exception as e:
        logger.error(f"Matchmaking stress test runner failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())