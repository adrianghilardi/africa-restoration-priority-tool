import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("social", Path(__file__).resolve().parents[1]/"scripts"/"05_download_social.py")
social = importlib.util.module_from_spec(spec)
spec.loader.exec_module(social)


def row(year, value, label="Poverty headcount ratio at $3.00 a day (2021 PPP) (% of population)"):
    return dict(countryiso3code="AGO",date=str(year),value=value,country={"value":"Angola"},indicator={"value":label})


class SelectionTests(unittest.TestCase):
    def test_latest_nonmissing(self):
        got=social.most_recent([row(2020,30),row(2022,None),row(2021,40)], ["AGO"],2026)
        self.assertEqual(got[0]["observation_year"],2021)
    def test_cutoff(self):
        self.assertEqual(social.most_recent([row(2021,30),row(2025,40)],["AGO"],2022)[0]["poverty_pct"],30)
    def test_missing_not_zero(self):
        self.assertIsNone(social.most_recent([], ["AGO"],2026)[0]["poverty_pct"])
    def test_zero_is_real(self):
        self.assertEqual(social.most_recent([row(2021,0)],["AGO"],2026)[0]["poverty_pct"],0)
    def test_duplicate_rejected(self):
        with self.assertRaises(ValueError): social.most_recent([row(2021,30),row(2021,30)],["AGO"],2026)
    def test_changed_definition_rejected(self):
        with self.assertRaises(ValueError): social.most_recent([row(2021,30,"Old $1.90 threshold")],["AGO"],2026)
    def test_invalid_rate_rejected(self):
        with self.assertRaises(ValueError): social.most_recent([row(2021,101)],["AGO"],2026)


if __name__ == "__main__": unittest.main()
