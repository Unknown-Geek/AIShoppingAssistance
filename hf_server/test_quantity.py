from quantity_estimator import QuantityEstimator

q = QuantityEstimator()

print(
    q.parse_ingredient(
        "▢ 2 cups (400 grams) aged basmati rice"
    )
)

print(
    q.parse_ingredient(
        "▢ ¾ cup carrots"
    )
)

print(
    q.parse_ingredient(
        "▢ 1 cup yogurt"
    )
)
print(q.parse_ingredient("green cardamom"))
print(q.parse_ingredient("bay leaf"))
print(q.parse_ingredient("green chili"))