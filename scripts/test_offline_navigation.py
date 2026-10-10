"""Checks road policies independently of the large OSM conversion."""
import unittest
from build_offline_navigation import policy


class PolicyTests(unittest.TestCase):
    def test_three_wheeler_excludes_expressways(self):
        self.assertEqual(policy({"highway": "motorway"})[2] & 2, 0)
        self.assertEqual(policy({"highway": "trunk", "motorroad": "yes"})[2] & 2, 0)
        self.assertEqual(policy({"highway": "residential"})[2] & 3, 3)

    def test_access_and_conditional_roads_excluded(self):
        for tags in [{"access": "private"}, {"motor_vehicle": "no"},
                     {"motorcar": "destination"}, {"access:conditional": "yes @ (Mo-Fr)"},
                     {"oneway:motorcar:conditional": "yes @ (Mo-Fr)"}]:
            self.assertIsNone(policy({"highway": "primary", **tags}))
        self.assertIsNone(policy({"highway": "footway"}))

    def test_oneway_and_vehicle_direction_overrides(self):
        self.assertEqual(policy({"highway": "primary", "oneway": "-1"})[3:], (False, True))
        self.assertEqual(policy({"highway": "residential", "motorcar:forward": "no"})[3:], (False, True))
        self.assertEqual(policy({"highway": "primary", "junction": "roundabout"})[3:], (True, False))

    def test_speed_and_access_override(self):
        self.assertEqual(policy({"highway": "primary", "maxspeed": "20"})[1], 20)
        self.assertIsNotNone(policy({"highway": "primary", "access": "no", "motorcar": "yes"}))


if __name__ == "__main__":
    unittest.main()
