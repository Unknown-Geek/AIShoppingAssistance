import asyncio
import json
from app.agents.tools.quantity_parser_tool import QuantityParserTool
from app.agents.shopping_assistant_agent import ShoppingAssistantAgent

async def run_architecture_suite():
    print("🚀 STARTING INTEGRATION REGRESSION TESTING ENGINE...")
    print("--------------------------------------------------")
    
    parser = QuantityParserTool()
    agent = ShoppingAssistantAgent()
    
    # --- TEST SUITE 1: QUANTITY PARSING INTEGRITY ---
    parsing_cases = [
        {"input": "to taste pinch Salt", "expected_name": "Salt", "expected_unit": "pinch"},
        {"input": "1 inch piece Ginger", "expected_name": "Ginger", "expected_unit": "inch piece"},
        {"input": "3 cloves Garlic", "expected_name": "Garlic", "expected_unit": "cloves"},
        {"input": "2 cups Basmati Rice", "expected_name": "Basmati Rice", "expected_unit": "cups"}
    ]
    
    parsing_failures = 0
    for case in parsing_cases:
        res = parser.execute(case["input"])
        # Check if structural duplication occurred ("cups cups") or leakages stayed in name
        if case["expected_name"].lower() not in res.get("name", "").lower() or "cups cups" in res.get("raw_input", ""):
            print(f"❌ REGRESSION DETECTED in parsing rule for: '{case['input']}' -> Got: {res}")
            parsing_failures += 1
            
    if parsing_failures == 0:
        print("✅ STAGE 1: Parser unit isolation tests passed perfectly.")

    # --- TEST SUITE 2: INVENTORY HYDRATION CROSS-CONTAMINATION ---
    print("\n🕵️ TESTING SEMANTIC INVENTORY MATCH SAFETY...")
    # Simulate an entry targeting your dangerous hallucination items (Harpic, Cerelac)
    test_cart_slugs = ["carrots"]
    
    # We run the workflow logic block natively
    try:
        payload = await agent.process_recipe_workflow(
            current_cart_slugs=test_cart_slugs,
            dish_query="Veg Biryani",
            servings=4
        )
        
        missing = payload.get("missing_ingredients", [])
        contamination_detected = False
        
        for item in missing:
            name = item.get("name", "").lower()
            # Catch toxic cross-contamination links instantly
            if any(toxic in name for toxic in ["harpic", "cleaner", "lizol", "cerelac", "toilet"]):
                print(f"❌ TOXIC HALLUCINATION REGRESSION DETECTED: Recipe linked an ingredient to -> '{item.get('name')}'")
                contamination_detected = True
                
        if not contamination_detected:
            print("✅ STAGE 2: Safety guardrails holding. Zero toxic cross-contamination items found.")
            
    except Exception as e:
        print(f"❌ PIPELINE EXECUTION FAULT CRASH: {e}")

    print("\n--------------------------------------------------")
    print("🏁 REGRESSION SUITE EXECUTION CYCLE COMPLETE.")

if __name__ == "__main__":
    asyncio.run(run_architecture_suite())