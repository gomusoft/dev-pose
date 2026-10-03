import unittest
from discord_sync import plan_project

def ch(i, name, type=0, parent=None):
    return {"id": i, "name": name, "type": type, "parent_id": parent}

class PlanTests(unittest.TestCase):
    def test_renames_legacy_and_creates_missing(self):
        chans = [ch("1", "Acme - Collab", 4), ch("2", "playgroud", parent="1"),
                 ch("3", "design", parent="1"), ch("4", "ai-updates", parent="1"),
                 ch("5", "notes", parent="1")]
        p = {"name": "Acme Shop", "code": "as", "category": "Acme - Collab"}
        ops, notes = plan_project(p, chans)
        kinds = [(o["op"], o.get("to") or o["name"]) for o in ops]
        self.assertIn(("rename_category", "Acme Shop"), kinds)
        self.assertIn(("rename_channel", "as-playground"), kinds)
        self.assertIn(("rename_channel", "as-design-and-specs"), kinds)
        self.assertIn(("rename_channel", "as-ai-updates"), kinds)
        self.assertIn(("create_channel", "as-talk"), kinds)
        self.assertIn(("create_channel", "as-ai-alerts"), kinds)
        self.assertEqual(notes, ["left alone (no mapping): #notes"])

    def test_explicit_map_and_idempotent(self):
        chans = [ch("1", "Acme Shop", 4), ch("2", "as-talk", parent="1"),
                 ch("3", "as-design-and-specs", parent="1"), ch("4", "as-playground", parent="1"),
                 ch("5", "as-ai-updates", parent="1"), ch("6", "feedback", parent="1")]
        p = {"name": "Acme Shop", "code": "as", "category": "Acme Shop", "map": {"feedback": "ai-alerts"}}
        ops, _ = plan_project(p, chans)
        self.assertEqual([(o["op"], o["to"]) for o in ops], [("rename_channel", "as-ai-alerts")])
        chans[5]["name"] = "as-ai-alerts"
        self.assertEqual(plan_project(p, chans)[0], [])

    def test_collision_warning_and_missing_category(self):
        chans = [ch("1", "Acme Shop", 4), ch("9", "Other", 4), ch("8", "as-talk", parent="9")]
        ops, notes = plan_project({"name": "Acme Shop", "code": "as", "category": "Acme Shop"}, chans)
        self.assertTrue(any("collision" in n for n in notes))
        with self.assertRaises(ValueError):
            plan_project({"name": "X", "code": "x", "category": "Nope"}, chans)

if __name__ == "__main__":
    unittest.main()
