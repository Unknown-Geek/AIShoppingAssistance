from quantity_estimator import QuantityEstimator

q = QuantityEstimator()

print(q.scale_quantity("400 grams", 2))
print(q.scale_quantity("2 tablespoons", 3))
print(q.scale_quantity("½ teaspoon", 2))