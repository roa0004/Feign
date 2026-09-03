const axios = require('axios');
const fs = require('fs');
const path = require('path');
const Logger = require('./logger');

class LLMManager {
  constructor() {
    this.logger = new Logger();
    this.ollamaUrl = process.env.OLLAMA_URL || 'http://localhost:11434';
    this.model = process.env.OLLAMA_MODEL || 'mistral';
    this.contextLength = process.env.OLLAMA_CONTEXT_LENGTH || 2048;
    
    // Load Rei-chan's core character
    this.characterPrompt = this.loadCharacterPrompt();
    this.systemRules = this.loadSystemRules();
  }

  loadCharacterPrompt() {
    try {
      const filePath = path.join(__dirname, '../personas/rei/character.txt');
      return fs.readFileSync(filePath, 'utf-8');
    } catch (err) {
      this.logger.error('Failed to load character prompt', err);
      return 'You are Rei-chan, a helpful AI companion.';
    }
  }

  loadSystemRules() {
    try {
      const filePath = path.join(__dirname, '../system/system_rules.txt');
      return fs.readFileSync(filePath, 'utf-8');
    } catch (err) {
      this.logger.error('Failed to load system rules', err);
      return '';
    }
  }

  buildPrompt(context) {
    const { userMessage, relevantMemories, searchResults, emotionState, presenceSummary } = context;
    
    let prompt = this.characterPrompt;
    prompt += '\n\n' + this.systemRules;
    
    if (relevantMemories && relevantMemories.length > 0) {
      prompt += '\n\n## Relevant Memories:\n';
      relevantMemories.forEach(memory => {
        prompt += `- ${memory.content}\n`;
      });
    }
    
    if (searchResults && searchResults.length > 0) {
      prompt += '\n\n## Search Results (verified):\n';
      searchResults.forEach(result => {
        prompt += `- ${result.title}: ${result.summary}\n`;
      });
    }
    
    if (emotionState) {
      prompt += `\n\n## Current Emotional State: ${emotionState}\n`;
    }

    if (presenceSummary) {
      prompt += `\n\n## Conversation Presence:\n${presenceSummary}\n`;
    }
    
    prompt += `\n\nUser: ${userMessage}\n`;
    prompt += `Rei-chan: `;
    
    return prompt;
  }

  async generateResponse(context) {
    try {
      const prompt = this.buildPrompt(context);
      
      const response = await axios.post(`${this.ollamaUrl}/api/generate`, {
        model: this.model,
        prompt: prompt,
        stream: false,
        temperature: 0.7,
        top_p: 0.9,
        num_predict: 256
      }, {
        timeout: 30000
      });
      
      const text = response.data.response.trim();
      this.logger.info(`LLM Response: ${text.substring(0, 100)}...`);
      return text;
    } catch (err) {
      this.logger.error('LLM generation error', err);
      return '……ごめん。ちょっと調子が悪いみたい。';
    }
  }

  async checkConnectivity() {
    try {
      const response = await axios.get(`${this.ollamaUrl}/api/tags`, { timeout: 5000 });
      return response.status === 200;
    } catch (err) {
      this.logger.warn('Ollama not reachable', err);
      return false;
    }
  }
}

module.exports = LLMManager;
