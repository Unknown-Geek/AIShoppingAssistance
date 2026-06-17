from quantity_estimator import QuantityEstimator

q = QuantityEstimator()

samples = [
    "1 bay leaf",
    "2 tablespoons mint leaves",
    "½ teaspoon salt",
    "400 grams basmati rice"
]

for item in samples:
    print(q.parse_ingredient(item))