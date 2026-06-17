from recipe_parser import RecipeParser

parser = RecipeParser()

print(
    parser.extract_servings(
        "Prep time 20 mins\nServes 4\nCook time 30 mins"
    )
)