const functions = require('firebase-functions');
const admin = require('firebase-admin');
const OpenAI = require('openai');

admin.initializeApp();

// Initialize OpenAI
// The API key is set via: firebase functions:config:set openai.key="YOUR_KEY"
const openai = new OpenAI({
  apiKey: functions.config().openai?.key,
});

const db = admin.firestore();

// Cost limits (in USD)
const FREE_USER_LIMIT = 0.10;  // Show paywall at $0.10
const SUBSCRIBED_USER_LIMIT = 0.50;  // Hard stop at $0.50 per billing period

/**
 * Get user's total OpenAI costs for current billing period (monthly)
 */
async function getUserCosts(uid) {
  // Get start of current month
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  
  const costsSnapshot = await db
    .collection('llm_cost')
    .where('uid', '==', uid)
    .where('ts', '>=', startOfMonth)
    .get();
  
  let totalCost = 0;
  costsSnapshot.docs.forEach(doc => {
    totalCost += doc.data().cost_usd || 0;
  });
  
  return totalCost;
}

/**
 * Check if user is subscribed (has active subscription)
 */
async function isUserSubscribed(uid) {
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    
    const userData = userDoc.data();
    return userData.isPro === true || userData.subscribed === true;
  } catch (e) {
    console.error('Error checking subscription:', e);
    return false;
  }
}

/**
 * Check if user has exceeded their cost limit
 * Throws HttpsError if limit exceeded
 */
async function checkCostLimit(uid, functionName) {
  const totalCost = await getUserCosts(uid);
  const isSubscribed = await isUserSubscribed(uid);
  
  console.log(`[${functionName}] User ${uid}: spent $${totalCost.toFixed(4)} this month, subscribed: ${isSubscribed}`);
  
  // Check hard limit for subscribed users
  if (isSubscribed && totalCost >= SUBSCRIBED_USER_LIMIT) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `You've reached your monthly usage limit of $${SUBSCRIBED_USER_LIMIT.toFixed(2)}. Your limit will reset at the start of next month.`
    );
  }
  
  // Check limit for free users
  if (!isSubscribed && totalCost >= FREE_USER_LIMIT) {
    throw new functions.https.HttpsError(
      'permission-denied',
      `You've reached the free usage limit. Subscribe to continue using AI features.`
    );
  }
  
  return { totalCost, isSubscribed };
}

/**
 * Classify an annoyance transcript
 * Input: { text: string }
 * Output: { category: string, trigger: string, safe: boolean }
 */
exports.classifyAnnoyance = functions.https.onCall(async (data, context) => {
  const { text } = data;

  if (!text || typeof text !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Text is required');
  }

  // Check authentication
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check cost limits before making API call
  await checkCostLimit(context.auth.uid, 'classifyAnnoyance');

  const startTime = Date.now();
  let tokensIn = 0;
  let tokensOut = 0;

  try {
    const prompt = `You classify short annoyance transcripts for a self-help app. Output strict JSON.
Categories: ["Boundaries","Environment","Systems Debt","Communication","Energy"].
Extract the shortest concrete trigger phrase that caused the annoyance.
If unsafe (self-harm, violence, abuse), set safe:false.

User transcript: "${text}"

Output: {"category":"...","trigger":"...","safe":true}`;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful assistant that classifies annoyances. Always respond with valid JSON only.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.3,
      max_tokens: 150,
    });

    tokensIn = response.usage?.prompt_tokens || 0;
    tokensOut = response.usage?.completion_tokens || 0;

    const content = response.choices[0].message.content.trim();
    
    // Try to parse JSON from the response
    let result;
    try {
      // Handle case where response might be wrapped in markdown code blocks
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        result = JSON.parse(content);
      }
    } catch (parseError) {
      console.error('Failed to parse OpenAI response:', content);
      // Fallback to default
      result = {
        category: 'Environment',
        trigger: text.slice(0, 30),
        safe: true,
      };
    }

    // Validate category
    const validCategories = ['Boundaries', 'Environment', 'Systems Debt', 'Communication', 'Energy'];
    if (!validCategories.includes(result.category)) {
      result.category = 'Environment';
    }

    // Log cost
    const cost = ((tokensIn * 0.00015) + (tokensOut * 0.0006)) / 1000; // gpt-4o-mini pricing
    const duration = Date.now() - startTime;

    if (context.auth?.uid) {
      await db.collection('llm_cost').add({
        uid: context.auth.uid,
        ts: admin.firestore.FieldValue.serverTimestamp(),
        model: 'gpt-4o-mini',
        tokens_in: tokensIn,
        tokens_out: tokensOut,
        cost_usd: cost,
        duration_ms: duration,
        function: 'classifyAnnoyance',
        cache_hit: false,
      });
    }

    return result;
  } catch (error) {
    console.error('Error classifying annoyance:', error);
    
    // Return safe defaults on error
    return {
      category: 'Environment',
      trigger: text.slice(0, 30),
      safe: true,
    };
  }
});

/**
 * Generate a suggestion based on user context
 * Input: { uid: string, category: string, trigger: string }
 * Output: { type: string, text: string, days: number }
 */
exports.generateSuggestion = functions.https.onCall(async (data, context) => {
  const { uid, category, trigger } = data;

  if (!uid || !category || !trigger) {
    throw new functions.https.HttpsError('invalid-argument', 'uid, category, and trigger are required');
  }

  // Check authentication
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check cost limits before making API call
  await checkCostLimit(uid, 'generateSuggestion');

  const startTime = Date.now();
  let tokensIn = 0;
  let tokensOut = 0;

  try {
    // Get recent annoyances for context
    const annoyancesSnapshot = await db
      .collection('annoyances')
      .where('uid', '==', uid)
      .orderBy('ts', 'desc')
      .limit(7)
      .get();

    const recentAnnoyances = annoyancesSnapshot.docs.map(doc => {
      const data = doc.data();
      return `${data.category}: ${data.trigger}`;
    }).join('\n');

    // Get past suggestions for resonance
    const suggestionsSnapshot = await db
      .collection('suggestions')
      .where('uid', '==', uid)
      .orderBy('ts', 'desc')
      .limit(10)
      .get();

    const resonanceSummary = suggestionsSnapshot.docs
      .filter(doc => doc.data().resonance)
      .map(doc => {
        const data = doc.data();
        return `${data.type}: ${data.resonance}`;
      })
      .join(', ');

    // Build context (keep under 800 chars)
    let contextStr = `Recent patterns:\n${recentAnnoyances}`;
    if (resonanceSummary) {
      contextStr += `\nPast resonance: ${resonanceSummary}`;
    }
    contextStr = contextStr.slice(0, 800);

    const prompt = `You propose one concise suggestion in a friendly, direct tone. You may output either a mindset reframe (shift in interpretation) or a specific daily behavior (doable in <30 minutes). No therapy or medical advice. Use the template:
"When ${trigger} happens, do/say/think {{suggestion}} for {{days}} days to reduce ${category} annoyances."

Context: ${contextStr}

Output JSON:
{ "type": "reframe"|"behavior", "text": "one sentence", "days": 3|5|7 }`;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful coach that provides actionable suggestions. Always respond with valid JSON only.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.7,
      max_tokens: 200,
    });

    tokensIn = response.usage?.prompt_tokens || 0;
    tokensOut = response.usage?.completion_tokens || 0;

    const content = response.choices[0].message.content.trim();
    
    // Try to parse JSON from the response
    let result;
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        result = JSON.parse(content);
      }
    } catch (parseError) {
      console.error('Failed to parse OpenAI response:', content);
      // Fallback
      result = {
        type: 'behavior',
        text: `When ${trigger} happens, take a 5-minute break to reset your focus.`,
        days: 5,
      };
    }

    // Validate
    if (!['reframe', 'behavior'].includes(result.type)) {
      result.type = 'behavior';
    }
    if (![3, 5, 7].includes(result.days)) {
      result.days = 5;
    }

    // Log cost
    const cost = ((tokensIn * 0.00015) + (tokensOut * 0.0006)) / 1000;
    const duration = Date.now() - startTime;

    await db.collection('llm_cost').add({
      uid: uid,
      ts: admin.firestore.FieldValue.serverTimestamp(),
      model: 'gpt-4o-mini',
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      cost_usd: cost,
      duration_ms: duration,
      function: 'generateSuggestion',
      cache_hit: false,
    });

    return result;
  } catch (error) {
    console.error('Error generating suggestion:', error);
    
    // Return safe default
    return {
      type: 'behavior',
      text: `When ${trigger} happens, take a moment to breathe and reassess.`,
      days: 5,
    };
  }
});

/**
 * Generate coaching recommendation based on user's full annoyance history
 * Input: { uid: string, timestamp: number }
 * Output: { recommendation: string, type: string, explanation: string }
 * Updated to remove fallback errors and expose real failures
 */
exports.generateCoaching = functions.https.onCall(async (data, context) => {
  const { uid, timestamp } = data;

  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid is required');
  }

  // Check authentication
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check cost limits before making API call (this is the most expensive call)
  await checkCostLimit(uid, 'generateCoaching');

  console.log(`[generateCoaching] Called for uid: ${uid} at ${new Date().toISOString()} (client timestamp: ${timestamp})`);

  const startTime = Date.now();
  let tokensIn = 0;
  let tokensOut = 0;

  try {
    // Get ALL user's annoyances (no time limit) for comprehensive pattern analysis
    const annoyancesSnapshot = await db
      .collection('annoyances')
      .where('uid', '==', uid)
      .orderBy('ts', 'desc')
      .limit(50) // Increased limit to capture more historical data
      .get();

    if (annoyancesSnapshot.empty) {
      throw new functions.https.HttpsError('failed-precondition', 'No annoyances found. Record at least 1 annoyance to get coaching.');
    }

    // Get past coaching (all of them, not just with resonance)
    // Query without orderBy to avoid index requirement - sort in memory instead
    const coachingSnapshot = await db
      .collection('coaching')
      .where('uid', '==', uid)
      .get();
    
    // Sort by timestamp manually
    const sortedCoachingDocs = coachingSnapshot.docs.sort((a, b) => {
      const aTime = a.data().ts?.toMillis() || 0;
      const bTime = b.data().ts?.toMillis() || 0;
      return bTime - aTime; // desc
    }).slice(0, 20);

    const allPastCoaching = sortedCoachingDocs.map(doc => {
      const data = doc.data();
      return {
        recommendation: data.recommendation,
        resonance: data.resonance,
        type: data.type
      };
    });
    
    // Check if this is the FIRST coaching (special onboarding experience)
    const isFirstCoaching = allPastCoaching.length === 0;

    // Separate what worked from what didn't
    const hellYes = allPastCoaching.filter(c => c.resonance === 'hell_yes').map(c => c.recommendation);
    const meh = allPastCoaching.filter(c => c.resonance === 'meh').map(c => c.recommendation);
    const allPrevious = allPastCoaching.map(c => c.recommendation);

    // Analyze patterns
    const annoyances = annoyancesSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        category: data.category,
        trigger: data.trigger,
        transcript: data.transcript
      };
    });

    // Group by category
    const categoryCount = {};
    annoyances.forEach(a => {
      categoryCount[a.category] = (categoryCount[a.category] || 0) + 1;
    });

    // Build comprehensive analysis summary
    const totalCount = annoyances.length;
    const topCategory = Object.keys(categoryCount).sort((a, b) => categoryCount[b] - categoryCount[a])[0];
    const topCategoryPercent = Math.round((categoryCount[topCategory] / totalCount) * 100);
    
    // Include ALL annoyances in the prompt for comprehensive pattern analysis
    const allAnnoyancesList = annoyances.map(a => 
      `${a.category}: "${a.trigger}"`
    ).join('\n');
    
    // Determine confidence level based on data quantity
    let confidenceLevel = 'low';
    let patternStrength = 'weak';
    if (totalCount >= 20) {
      confidenceLevel = 'high';
      patternStrength = 'strong';
    } else if (totalCount >= 10) {
      confidenceLevel = 'medium';
      patternStrength = 'moderate';
    }

    let resonanceFeedback = '';
    if (allPrevious.length > 0) {
      resonanceFeedback += `\n\nPrevious recommendations you've given (DO NOT REPEAT - give something DIFFERENT):\n${allPrevious.slice(0, 10).join('\n')}`;
    }
    if (hellYes.length > 0) {
      resonanceFeedback += `\n\nRecommendations they LOVED (use similar style/approach):\n${hellYes.join('\n')}`;
    }
    if (meh.length > 0) {
      resonanceFeedback += `\n\nRecommendations that didn't resonate (avoid similar approach):\n${meh.join('\n')}`;
    }

    const timestamp = Date.now();
    const randomSeed = Math.floor(Math.random() * 1000000);
    
    // Special instructions for the FIRST coaching (onboarding + education)
    let firstCoachingInstructions = '';
    if (isFirstCoaching) {
      firstCoachingInstructions = `
      
SPECIAL: This is their FIRST coaching session! Make it educational and onboarding-friendly.

In your explanation, naturally weave in these educational points to help them understand how the system works:

1. CATEGORIES: Explain that every annoyance gets automatically categorized into one of 5 types: Boundaries (personal limits, saying no), Environment (physical space, noise), Life Systems (routines, organization), Communication (expressing yourself, being heard), and Energy (emotional state, motivation). They can see patterns forming through these color-coded categories.

2. TWO-PART COACHING: Explain that every coaching includes BOTH a mindset shift (a new way of thinking) AND an action step (concrete behavior change). The mindset shift helps them see situations differently, while the action step gives them something practical to implement today.

3. THE PROCESS: Explain how this works: They capture what annoys them as it happens (raw and unfiltered), then after every 5 entries, AI analyzes their patterns and identifies themes, then they get personalized coaching with both mindset + action, and finally they apply it and feel the difference.

4. PRIVACY: Mention that their audio never leaves their phone - only redacted text is sent for AI coaching, keeping their data private and secure.

Weave these educational points NATURALLY into your explanation - don't make it feel like a manual. Make it feel like you're teaching them while coaching them. This is their first experience with the system, so help them understand what's happening while also giving them real value.`;
    }
    
    const prompt = `You are a direct, no-BS coach analyzing someone's annoyance patterns.

[Request ID: ${timestamp}-${randomSeed}] - This is a NEW request. You must give a COMPLETELY DIFFERENT recommendation than any previous ones.${firstCoachingInstructions}

DATA ANALYSIS:
- Total annoyances analyzed: ${totalCount} (${confidenceLevel} confidence level)
- Pattern strength: ${patternStrength}
- Top issue: ${topCategory} (${topCategoryPercent}% of ${totalCount} annoyances)
- ALL their recorded triggers (most recent first):
${allAnnoyancesList}${resonanceFeedback}

CRITICAL REQUIREMENTS:
1. Your recommendation MUST be COMPLETELY DIFFERENT from any "Previous recommendations" listed above
2. Your recommendation MUST directly address the SPECIFIC triggers in their list
3. Look at the FULL LIST of triggers to identify the underlying pattern
4. Prescribe a fix that addresses THOSE EXACT situations
5. CONFIDENCE ADAPTATION: With ${totalCount} annoyances, you have ${confidenceLevel} confidence in the patterns. ${totalCount < 5 ? 'Be more exploratory and educational since patterns are still emerging.' : totalCount < 20 ? 'You can identify clear patterns and give targeted advice.' : 'You have strong evidence of established patterns - be confident and specific in your recommendations.'}

For example, if they listed "coworker interrupts me in meetings" as a trigger, your recommendation should address THAT SPECIFIC SITUATION, not just "be more assertive in general."

Give them ONE specific action or mindset reframe. Be CONCRETE and ACTIONABLE - not corporate speak. Each recommendation must be UNIQUE.

Good examples:
- "When someone interrupts you in meetings, say 'Let me finish this thought' and keep talking."
- "Every morning, spend 10 minutes clearing inbox to zero before starting work."
- "Stop treating every request as urgent. Ask yourself: 'What happens if I do this tomorrow?'"

Bad examples (too vague):
- "Prioritize proactive management"
- "Be more assertive"
- "Focus on time management"

The recommendation should stand alone. The explanation is supporting commentary.

IMPORTANT JSON FORMATTING:
- Do NOT use curly braces in your text content
- Keep all text on single lines (use spaces instead of literal newlines)
- Ensure all quotes are properly escaped

Respond in JSON:
{
  "recommendation": "2-3 sentences max. Specific action or mindset shift that directly addresses their actual triggers.",
  "type": "mindset_shift" or "behavior_change",
  "explanation": "Write at least 5-6 full paragraphs (minimum 500 words) of supporting commentary. DIRECTLY REFERENCE their specific triggers by name throughout the explanation. Show how this fix applies to their exact situations. Explain the psychology behind their reactions to these specific triggers, concrete examples of implementing this in the situations they described, what they'll notice when they try it, and how this creates lasting change. Write naturally and conversationally - don't use section headers or numbered lists. Just flow from one insight to the next, building a complete understanding."
}`;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a direct, actionable coach. No corporate jargon. Specific recommendations only. Always respond with valid JSON ONLY - no markdown, no extra text. Do NOT use curly braces in your text content. IMPORTANT: Each time you're called, you must give a COMPLETELY DIFFERENT recommendation than before. Timestamp: ${Date.now()} - Random seed: ${Math.random()} - Be creative and varied.`,
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 1.0,
      max_tokens: 2000,
      response_format: { type: "json_object" }
    });

    tokensIn = response.usage?.prompt_tokens || 0;
    tokensOut = response.usage?.completion_tokens || 0;

    const content = response.choices[0].message.content.trim();
    
    // Parse JSON from the response - handle markdown code blocks and newlines
    let result;
    try {
      // Remove markdown code block markers and extract just the JSON
      let jsonText = content.trim();
      
      // Remove leading ```json or ``` and trailing ```
      jsonText = jsonText.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/\s*```$/, '').trim();
      
      // Find the JSON object boundaries
      const firstBrace = jsonText.indexOf('{');
      const lastBrace = jsonText.lastIndexOf('}');
      
      if (firstBrace !== -1 && lastBrace !== -1) {
        jsonText = jsonText.substring(firstBrace, lastBrace + 1);
      }
      
      // Fix JSON by properly escaping string values character by character
      let fixed = '';
      let inString = false;
      let afterColon = false;
      
      for (let i = 0; i < jsonText.length; i++) {
        const char = jsonText[i];
        const prevChar = i > 0 ? jsonText[i - 1] : '';
        
        // Track if we're in a string value (not a key)
        if (char === '"' && prevChar !== '\\') {
          inString = !inString;
          if (!inString) {
            afterColon = false;
          }
          fixed += char;
        } else if (!inString && char === ':') {
          afterColon = true;
          fixed += char;
        } else if (inString && afterColon) {
          // We're in a string value - escape special characters
          if (char === '\n') {
            fixed += '\\n';
          } else if (char === '\r') {
            fixed += '\\r';
          } else if (char === '\t') {
            fixed += '\\t';
          } else if (char === '\\' && i + 1 < jsonText.length && jsonText[i + 1] !== '"' && jsonText[i + 1] !== '\\' && jsonText[i + 1] !== 'n' && jsonText[i + 1] !== 'r' && jsonText[i + 1] !== 't') {
            // Escape backslashes that aren't already escaping something
            fixed += '\\\\';
          } else {
            fixed += char;
          }
        } else {
          fixed += char;
        }
      }
      
      // Parse the fixed JSON
      result = JSON.parse(fixed);
      console.log('[generateCoaching] Successfully parsed response');
    } catch (parseError) {
      console.error('[generateCoaching] Parse error:', parseError.message);
      console.error('[generateCoaching] Content length:', content.length);
      console.error('[generateCoaching] Content start:', content.substring(0, 300));
      console.error('[generateCoaching] Content end:', content.substring(Math.max(0, content.length - 300)));
      throw new functions.https.HttpsError('internal', `Failed to parse AI response: ${parseError.message}`);
    }

    // Validate type
    if (!['mindset_shift', 'behavior_change'].includes(result.type)) {
      result.type = 'mindset_shift';
    }
    
    // Mark if this is the first coaching (so app can skip prompt screen)
    result.isFirstCoaching = isFirstCoaching;

    // Log cost
    const cost = ((tokensIn * 0.00015) + (tokensOut * 0.0006)) / 1000;
    const duration = Date.now() - startTime;

    await db.collection('llm_cost').add({
      uid: uid,
      ts: admin.firestore.FieldValue.serverTimestamp(),
      model: 'gpt-4o-mini',
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      cost_usd: cost,
      duration_ms: duration,
      function: 'generateCoaching',
      cache_hit: false,
    });

    return result;
  } catch (error) {
    console.error('Error generating coaching:', error);
    // Re-throw all errors so we can see what's actually failing
    throw error;
  }
});

/**
 * Get user's current cost usage and limits
 * Input: { uid: string }
 * Output: { currentCost: number, limit: number, isSubscribed: boolean, canUseAI: boolean }
 */
exports.getUserCostStatus = functions.https.onCall(async (data, context) => {
  const { uid } = data;

  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid is required');
  }

  // Check authentication
  if (!context.auth?.uid || context.auth.uid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
  }

  try {
    const currentCost = await getUserCosts(uid);
    const isSubscribed = await isUserSubscribed(uid);
    const limit = isSubscribed ? SUBSCRIBED_USER_LIMIT : FREE_USER_LIMIT;
    const canUseAI = currentCost < limit;

    return {
      currentCost: parseFloat(currentCost.toFixed(4)),
      limit,
      isSubscribed,
      canUseAI,
      percentUsed: Math.round((currentCost / limit) * 100),
    };
  } catch (error) {
    console.error('Error getting user cost status:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get cost status');
  }
});
