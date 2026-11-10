import unittest
from unittest.mock import patch
import tracker

class TrackerTests(unittest.TestCase):
    def setUp(self):
        tracker.CACHE.clear()
        tracker.BUDGET.clear()

    def test_normalizes_only_completed_participant_and_keeps_real_equipment(self):
        document = {"metadata":{"match_id":"EUW1_fixture"},"info":{
            "game_datetime":1730000000000,"game_length":1814.5,"queue_id":1100,"tft_set_number":18,
            "participants":[{"puuid":"other","placement":1},{"puuid":"fixture","placement":3,
               "last_round":31,"gold_left":3,"total_damage_to_players":61,"players_eliminated":2,
               "units":[{"character_id":"DA_18_Ahri","tier":2,"itemNames":["DA_SpearOfShojin"]}],
               "traits":[{"name":"active","tier_current":2,"num_units":4},{"name":"inactive","tier_current":0}]}]}}
        result = tracker.normalized_match(document,"fixture")
        self.assertEqual(result["placement"],3)
        self.assertEqual(result["timestamp"],1730000000)
        self.assertEqual(result["duration"],1814.5)
        self.assertEqual(result["lastRound"],31)
        self.assertEqual(result["goldLeft"],3)
        self.assertEqual(result["playerDamage"],61)
        self.assertEqual(result["playersEliminated"],2)
        self.assertIsNone(tracker.normalized_match(document,"other")["lastRound"])
        self.assertEqual(result["units"][0]["items"],["DA_SpearOfShojin"])
        self.assertEqual([x["key"] for x in result["traits"]],["active"])
        self.assertIsNone(tracker.normalized_match(document,"missing"))

    def test_routes_through_account_rank_and_completed_matches(self):
        calls = []
        def riot(host,path):
            calls.append((host,path))
            if "/accounts/" in path:
                return {"puuid":"fixture","gameName":"Pseudo","tagLine":"EUW"}
            if "/league/" in path:
                return [{"queueType":"RANKED_TFT","tier":"GOLD","rank":"I","leaguePoints":42,"wins":2,"losses":4}]
            if "/ids?" in path:
                return []
            self.fail(path)
        with patch.object(tracker,"riot",side_effect=riot):
            profile=tracker.tracker({"name":"Pseudo","tag":"EUW","region":"euw1"})
            self.assertEqual(tracker.tracker({"name":"pseudo","tag":"euw","region":"euw1"}),profile)
        self.assertEqual(profile["ranks"][0]["lp"],42)
        self.assertEqual([host for host,_ in calls],["europe","euw1","europe"])
        self.assertIn("count=100",calls[-1][1])

    def test_rejects_nonallowlisted_region_before_riot(self):
        with patch.object(tracker,"riot") as riot:
            with self.assertRaises(tracker.GatewayError):
                tracker.tracker({"name":"Pseudo","tag":"EUW","region":"example.net"})
            riot.assert_not_called()

if __name__ == "__main__":
    unittest.main()
