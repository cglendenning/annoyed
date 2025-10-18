# Firebase Cloud Functions

This directory contains the backend Firebase Cloud Functions for the Annoyed app.

## Functions

### `classifyAnnoyance`
Classifies user annoyance transcripts into categories using OpenAI's GPT-4o-mini.

**Input:** `{ text: string }`  
**Output:** `{ category: string, trigger: string, safe: boolean }`

### `generateSuggestion`
Generates actionable suggestions based on user's annoyance category and trigger.

**Input:** `{ uid: string, category: string, trigger: string }`  
**Output:** `{ type: string, text: string, days: number }`

### `generateCoaching`
Analyzes user's annoyance patterns and generates personalized coaching insights.

**Input:** `{ uid: string, timestamp: number }`  
**Output:** `{ recommendation: string, type: string, explanation: string }`

### `getUserCostStatus`
Returns user's current OpenAI API usage and limits.

**Input:** `{ uid: string }`  
**Output:** `{ currentCost: number, limit: number, isSubscribed: boolean, canUseAI: boolean, percentUsed: number }`

## Cost Management

- Free users: $0.10 limit per month
- Subscribed users: $0.50 limit per month
- Costs automatically reset at the start of each month
- All costs are logged in the `llm_cost` Firestore collection

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Set OpenAI API key:
   ```bash
   firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY"
   ```

3. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

## Local Development

1. Get config:
   ```bash
   firebase functions:config:get > .runtimeconfig.json
   ```

2. Run emulator:
   ```bash
   firebase emulators:start --only functions
   ```

## Model Used

All functions use **gpt-4o-mini** with the following pricing:
- Input: $0.150 per 1M tokens
- Output: $0.600 per 1M tokens

## Data Analysis

The `generateCoaching` function analyzes:
- Last 7 days of annoyances (maximum 15)
- Category distribution
- Previous coaching feedback (hell_yes vs meh)
- Specific triggers and patterns

