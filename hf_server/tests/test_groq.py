from app.services.groq_client import GroqClient

client = GroqClient()

print(client.extract_recipe_request("I want Arrabiata for 2 people"))
print(client.extract_recipe_request("Make Chicken Curry for 4 people"))
print(client.extract_recipe_request("Prepare Veg Biryani for 5 persons"))