"""Download the raw series and build the two analysis datasets.

Run from the project root:
    python code/00_build_data.py

Writes data/uk_macro.csv and data/jordan_co2.csv. Raw downloads go to data/raw/,
which is not committed. The two built CSVs are committed so the Stata do-files
run without an internet connection.
"""

import json
import urllib.request
from pathlib import Path

import pandas as pd

RAW = Path("data/raw")
OUT = Path("data")

WB_URL = "https://api.worldbank.org/v2/country/{c}/indicator/{i}?format=json&per_page=200"
OWID_CO2 = "https://raw.githubusercontent.com/owid/co2-data/master/owid-co2-data.csv"
OWID_ENERGY = "https://raw.githubusercontent.com/owid/energy-data/master/owid-energy-data.csv"


def download(url, path):
    if not path.exists():
        print("downloading", url)
        urllib.request.urlretrieve(url, path)
    return path


def world_bank(country, indicator, name):
    path = download(WB_URL.format(c=country, i=indicator), RAW / f"wb_{country}_{indicator}.json")
    rows = json.loads(path.read_text())[1]
    s = pd.Series({int(r["date"]): r["value"] for r in rows}, name=name, dtype="float64")
    return s.sort_index()


def owid(url, filename, country, column, name):
    df = pd.read_csv(download(url, RAW / filename))
    df = df[df["country"] == country].set_index("year")[column]
    return df.rename(name)


RAW.mkdir(parents=True, exist_ok=True)

# UK, annual. Real GDP growth rather than nominal GDP, so that inflation does not
# drive the growth series. Exchange rate is GBP per US dollar, period average.
uk = pd.concat(
    [
        world_bank("GBR", "NY.GDP.MKTP.KD.ZG", "gdp_growth"),
        world_bank("GBR", "PA.NUS.FCRF", "exch_rate"),
        world_bank("GBR", "NE.EXP.GNFS.ZS", "exports_gdp"),
        world_bank("GBR", "NE.IMP.GNFS.ZS", "imports_gdp"),
    ],
    axis=1,
)
uk = uk.dropna().rename_axis("year").reset_index()
uk.to_csv(OUT / "uk_macro.csv", index=False)
print(f"uk_macro.csv: {len(uk)} years, {uk.year.min()}-{uk.year.max()}")

# Jordan, annual, in levels. Growth rates are computed in Stata.
# World Bank national-accounts trade for Jordan stops in 2007, so merchandise
# trade (WTO, via the World Bank) is used instead. Oil products consumption is no
# longer published, so total primary energy consumption (OWID, TWh) stands in.
jo = pd.concat(
    [
        owid(OWID_CO2, "owid-co2-data.csv", "Jordan", "co2", "co2_mt"),
        world_bank("JOR", "TX.VAL.MRCH.CD.WT", "exports_usd"),
        world_bank("JOR", "TM.VAL.MRCH.CD.WT", "imports_usd"),
        world_bank("JOR", "GC.NLD.TOTL.GD.ZS", "budget_bal_gdp"),
        owid(OWID_ENERGY, "owid-energy-data.csv", "Jordan", "primary_energy_consumption", "energy_twh"),
    ],
    axis=1,
)
jo = jo.loc[1990:].dropna().rename_axis("year").reset_index()
jo.to_csv(OUT / "jordan_co2.csv", index=False)
print(f"jordan_co2.csv: {len(jo)} years, {jo.year.min()}-{jo.year.max()}")
