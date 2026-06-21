import asyncio
from app.agents.missing_regulars_agent import MissingRegularsAgent

async def test():
    print("Initializing Agent...")
    agent = MissingRegularsAgent()
    user_id = "d5777910-84ac-4ac9-84a0-0819ad960378" # Synthetic User A
    print(f"Testing for user: {user_id}")
    
    orders = await agent.supabase.get_order_history(user_id=user_id, days=90)
    print(f"Fetched {len(orders)} orders for user.")
    
    result = await agent.analyze_cart(user_id, current_cart=[])
    
    print("\n=== RESULTS ===")
    print(f"Response Text:\n{result.get('response_text')}\n")
    print("Missing Items List:")
    for item in result.get('missing_regulars', []):
        print(f" - {item['name']} (Bought {item['frequency']} times, avg gap: {item['avg_gap_days']} days)")

if __name__ == "__main__":
    asyncio.run(test())
