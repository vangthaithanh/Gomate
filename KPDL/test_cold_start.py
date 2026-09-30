from cold_start_adapter import recommend_cold_start

result = recommend_cold_start(["THIEN_NHIEN", "BIEN_NUI", "GAN_TOI", "DANG_HOT"], latitude=10.8231, longitude=106.6297, top_k=5)
assert result["coldStart"] is True
assert len(result["recommendations"]) == 5
assert all(row["externalId"] for row in result["recommendations"])
print("[OK] cold-start test")
print("scoringMode=", result["scoringMode"])
for row in result["recommendations"]: print(row["externalId"], row["name"], row["score"])
