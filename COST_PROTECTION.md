# OpenAI Cost Protection System

## Overview
Comprehensive cost tracking and limits to prevent OpenAI API overage charges.

## Cost Limits

### Free Users
- **Limit**: $0.10
- **Action**: Show paywall when limit reached
- **Behavior**: User must subscribe to continue using AI features

### Subscribed Users (Pro)
- **Soft Warning**: At 75% usage ($0.375), show usage message
- **Hard Limit**: $0.50 per month
- **Action**: Block all AI features until next billing period
- **Reset**: Automatically resets on the 1st of each month

## Protected Functions

All three OpenAI API calls are protected:

1. **classifyAnnoyance** (~150 tokens, ~$0.0001 per call)
   - Called: Every time user records an annoyance
   - Categorizes the annoyance

2. **generateSuggestion** (~200 tokens, ~$0.0002 per call)
   - Called: When viewing suggestion cards
   - Generates actionable suggestions

3. **generateCoaching** (~2000 tokens, ~$0.002 per call)
   - Called: When accessing "Get Your Fix" coaching
   - Most expensive - generates detailed coaching

## Estimated Usage

Based on gpt-4o-mini pricing ($0.150/1M input tokens, $0.600/1M output tokens):

### Free Users ($0.10 limit)
- ~50 annoyance recordings
- ~10 coaching sessions
- Mix of both: ~30 annoyances + 5 coaching sessions

### Subscribed Users ($0.50 limit)
- ~250 annoyance recordings
- ~50 coaching sessions
- Mix of both: ~150 annoyances + 25 coaching sessions

## Implementation

### Firebase Functions (`functions/index.js`)
```javascript
// Cost limits
const FREE_USER_LIMIT = 0.10;
const SUBSCRIBED_USER_LIMIT = 0.50;

// Functions added:
- getUserCosts(uid) - Get monthly spend
- isUserSubscribed(uid) - Check subscription status
- checkCostLimit(uid, functionName) - Enforce limits
- getUserCostStatus(uid) - Get detailed usage info
```

### Flutter App

#### PaywallService (`lib/services/paywall_service.dart`)
- `getCostStatus(uid)` - Get user's current usage
- `shouldShowPaywall(uid, isPro)` - Determine if paywall should show
- `getUsageMessage(uid)` - Get user-friendly usage message

#### Error Handling
- Coaching screen automatically shows paywall on limit errors
- Clear error messages for users
- Graceful degradation on API failures

### Firestore Security Rules
```javascript
match /llm_cost/{costId} {
  // Users can read their own cost records
  allow read: if request.auth != null && 
                 request.auth.uid == resource.data.uid;
  // Only authenticated users (via Functions) can create
  allow create: if request.auth != null;
}
```

### Cost Tracking
Each API call logs to Firestore `llm_cost` collection:
```javascript
{
  uid: string,
  ts: timestamp,
  model: 'gpt-4o-mini',
  tokens_in: number,
  tokens_out: number,
  cost_usd: number,
  duration_ms: number,
  function: string,
  cache_hit: boolean
}
```

## Deployment Steps

1. **Deploy Firebase Functions**:
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

2. **Deploy Firestore Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Test the Limits**:
   - Create a test user
   - Record annoyances until limit hit
   - Verify paywall appears at $0.10

4. **Monitor Costs**:
   - Check Firebase Console > Firestore > `llm_cost` collection
   - Query for aggregated costs:
     ```javascript
     db.collection('llm_cost')
       .where('ts', '>=', startOfMonth)
       .get()
     ```

## User Experience

### Free User Journey
1. Sign up → Gets $0.10 free trial
2. Uses app normally (records annoyances, gets coaching)
3. At 90% ($0.09) → Warning message appears
4. At 100% ($0.10) → Paywall appears automatically
5. Subscribe → Gets $0.50/month limit

### Subscribed User Journey
1. Subscribe → Gets $0.50/month limit
2. Uses app normally throughout the month
3. At 75% ($0.375) → Usage warning appears
4. At 100% ($0.50) → Hard limit, must wait until next month
5. 1st of month → Limit resets automatically

## Error Messages

### Free User at Limit
> "You've used your free trial ($0.10 of $0.10). Subscribe to continue!"

### Subscribed User at Limit
> "You've reached your monthly limit of $0.50. Your usage will reset at the start of next month."

### Warning Message (75%+)
> "You've used 85% of your monthly usage ($0.43/$0.50)"

## Monitoring & Alerts

Consider setting up:
1. Cloud Function logs monitoring
2. Weekly cost reports
3. Alert if any user exceeds 80% of limit
4. Alert if total monthly OpenAI spend > $50

## Future Enhancements

1. **Caching**: Cache common responses to reduce costs
2. **Tiered Pricing**: Different limits for different subscription tiers
3. **Usage Dashboard**: Show users their detailed usage breakdown
4. **Smart Limits**: Adjust limits based on actual costs over time
5. **Bulk Discounts**: Lower limits for high-volume users

---

**Last Updated**: October 18, 2025  
**Cost Tracking**: Active  
**Limits Enforced**: Yes

