const { BaseRenderer } = require('./base');

/**
 * Markdown renderer - outputs markdown with YAML frontmatter
 */
class MarkdownRenderer extends BaseRenderer {
  /**
   * Render data as markdown with YAML frontmatter
   * @returns {string} Markdown string
   */
  render() {
    const { type } = this.data;

    switch (type) {
      case 'research':
        return this.renderResearch();
      case 'entries':
        return this.renderEntries();
      case 'categories':
        return this.renderCategories();
      case 'profiles':
        return this.renderProfiles();
      case 'providers':
        return this.renderProviders();
      case 'help':
        return this.renderHelp();
      case 'curate':
        return this.renderCurate();
      case 'create-category':
        return this.renderCreateCategory();
      case 'entry':
        return this.renderEntry();
      case 'delete':
        return this.renderDelete();
      case 'error':
        return this.renderError();
      default:
        return this.renderGeneric();
    }
  }

  /**
   * Build YAML frontmatter from an object
   * @param {Object} obj - Key-value pairs for frontmatter
   * @returns {string} YAML frontmatter block
   */
  buildFrontmatter(obj) {
    const lines = ['---'];
    for (const [key, value] of Object.entries(obj)) {
      if (value !== undefined && value !== null) {
        if (typeof value === 'string') {
          // Escape strings that might break YAML
          if (value.includes(':') || value.includes('#') || value.includes('\n')) {
            lines.push(`${key}: "${value.replace(/"/g, '\\"')}"`);
          } else {
            lines.push(`${key}: ${value}`);
          }
        } else if (typeof value === 'boolean' || typeof value === 'number') {
          lines.push(`${key}: ${value}`);
        } else {
          lines.push(`${key}: ${JSON.stringify(value)}`);
        }
      }
    }
    lines.push('---', '');
    return lines.join('\n');
  }

  /**
   * Render research query result
   */
  renderResearch() {
    const { provider, model, profile, tokens, saved, title, content, thinking, examples, sources } = this.data;
    const parts = [];

    // Frontmatter
    parts.push(this.buildFrontmatter({
      type: 'research',
      provider,
      model,
      profile,
      tokens,
      saved
    }));

    // Thinking (if requested)
    if (this.options.showThinking && thinking) {
      parts.push('## Thinking Process\n');
      parts.push(thinking);
      parts.push('\n---\n');
    }

    // Title and content
    if (title) {
      parts.push(`## ${title}\n`);
    }
    if (content) {
      parts.push(content);
      parts.push('');
    }

    // Examples
    if (examples && examples.length > 0) {
      parts.push('\n### Examples\n');
      for (const example of examples) {
        parts.push(`**${example.description}**`);
        parts.push('```' + (example.language || ''));
        parts.push(example.code);
        parts.push('```\n');
      }
    }

    // Sources
    if (sources && sources.length > 0) {
      parts.push('---\nSources:');
      for (const source of sources) {
        const num = source.number ? `[${source.number}] ` : '- ';
        parts.push(`  ${num}${source.title || source.url}`);
        if (source.url && source.title) {
          parts.push(`     ${source.url}`);
        }
      }
    }

    return parts.join('\n');
  }

  /**
   * Render entries list (unsaved or library)
   */
  renderEntries() {
    const { title, count, entries } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'entries',
      title,
      count: count || entries?.length || 0
    }));

    if (!entries || entries.length === 0) {
      parts.push(`No ${title.toLowerCase()} entries.`);
      return parts.join('\n');
    }

    // Table header
    parts.push('| ID | Profile | Title | Scope | Created |');
    parts.push('|----|---------|-------|-------|---------|');

    // Table rows
    for (const entry of entries) {
      const id = entry.id ? entry.id.slice(0, 8) : '-';
      const profile = entry.profile || '-';
      const entryTitle = (entry.title || entry.query || '-').slice(0, 40);
      const scope = entry.scope?.type === 'general' ? '[general]' : `[${entry.scope?.path || '-'}]`;
      const created = entry.created_at ? entry.created_at.split('T')[0] : '-';
      parts.push(`| ${id} | ${profile} | ${entryTitle} | ${scope} | ${created} |`);
    }

    return parts.join('\n');
  }

  /**
   * Render categories list
   */
  renderCategories() {
    const { categories } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'categories',
      count: categories?.length || 0
    }));

    if (!categories || categories.length === 0) {
      parts.push('No categories defined. Create one with --create-category');
      return parts.join('\n');
    }

    parts.push('## Categories\n');
    for (const cat of categories) {
      parts.push(`### ${cat.slug}`);
      parts.push(`- **ID**: ${cat.id}`);
      parts.push(`- **Description**: ${cat.description}`);
      if (cat.rules) {
        parts.push(`- **Rules**: ${cat.rules}`);
      }
      parts.push('');
    }

    return parts.join('\n');
  }

  /**
   * Render profiles list
   */
  renderProfiles() {
    const { profiles, defaultProfile } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'profiles',
      count: profiles?.length || 0,
      default: defaultProfile
    }));

    parts.push('## Available Profiles\n');
    for (const profile of profiles || []) {
      const marker = profile.name === defaultProfile ? ' (default)' : '';
      parts.push(`### ${profile.name}${marker}`);
      parts.push(profile.description);
      parts.push('');
    }

    return parts.join('\n');
  }

  /**
   * Render providers list
   */
  renderProviders() {
    const { providers } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'providers',
      count: providers?.length || 0
    }));

    parts.push('## Available Providers\n');
    for (const provider of providers || []) {
      const status = provider.available ? '✓ configured' : `✗ missing ${provider.envKey}`;
      parts.push(`### ${provider.displayName}`);
      parts.push(`- **Name**: ${provider.name}`);
      parts.push(`- **Status**: ${status}`);
      parts.push('');
    }

    return parts.join('\n');
  }

  /**
   * Render help text
   */
  renderHelp() {
    const { content } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'help'
    }));

    parts.push(content || '');

    return parts.join('\n');
  }

  /**
   * Render curate confirmation
   */
  renderCurate() {
    const { success, entry, category, message } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'curate',
      success
    }));

    if (success) {
      parts.push(`## Entry Curated\n`);
      parts.push(`Entry **${entry?.id}** moved to category **${category?.slug}**`);
      if (entry?.title) {
        parts.push(`\n- **Title**: ${entry.title}`);
      }
    } else {
      parts.push(`## Error\n`);
      parts.push(message || 'Failed to curate entry');
    }

    return parts.join('\n');
  }

  /**
   * Render create-category confirmation
   */
  renderCreateCategory() {
    const { success, category, message } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'create-category',
      success
    }));

    if (success) {
      parts.push(`## Category Created\n`);
      parts.push(`- **ID**: ${category?.id}`);
      parts.push(`- **Slug**: ${category?.slug}`);
      parts.push(`- **Description**: ${category?.description}`);
      if (category?.rules) {
        parts.push(`- **Rules**: ${category.rules}`);
      }
    } else {
      parts.push(`## Error\n`);
      parts.push(message || 'Failed to create category');
    }

    return parts.join('\n');
  }

  /**
   * Render single entry view
   */
  renderEntry() {
    const { entry } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'entry',
      id: entry.id,
      location: entry.location,
      profile: entry.profile,
      provider: entry.provider,
      model: entry.model
    }));

    parts.push(`## ${entry.title || entry.query}\n`);
    parts.push(`- **ID**: ${entry.id}`);
    parts.push(`- **Location**: ${entry.location || 'unknown'}`);
    parts.push(`- **Profile**: ${entry.profile}`);
    parts.push(`- **Provider**: ${entry.provider}`);
    parts.push(`- **Model**: ${entry.model}`);
    parts.push(`- **Query**: ${entry.query}`);
    parts.push(`- **Scope**: ${entry.scope?.type || 'unknown'}${entry.scope?.path ? ` (${entry.scope.path})` : ''}`);
    parts.push(`- **Created**: ${entry.created_at}`);
    if (entry.curated_at) parts.push(`- **Curated**: ${entry.curated_at}`);
    if (entry.category_id) parts.push(`- **Category ID**: ${entry.category_id}`);

    if (entry.content) {
      parts.push('\n### Content\n');
      parts.push(entry.content);
    }

    if (entry.thinking) {
      parts.push('\n### Thinking Process\n');
      parts.push(entry.thinking);
    }

    if (entry.examples && entry.examples.length > 0) {
      parts.push('\n### Examples\n');
      for (const example of entry.examples) {
        parts.push(`**${example.description}**`);
        parts.push('```' + (example.language || ''));
        parts.push(example.code);
        parts.push('```\n');
      }
    }

    if (entry.sources && entry.sources.length > 0) {
      parts.push('### Sources\n');
      for (const source of entry.sources) {
        const num = source.number ? `[${source.number}] ` : '- ';
        parts.push(`${num}${source.title || source.url}`);
        if (source.url && source.title) {
          parts.push(`   ${source.url}`);
        }
      }
    }

    return parts.join('\n');
  }

  /**
   * Render delete confirmation
   */
  renderDelete() {
    const { success, entry } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'delete',
      success
    }));

    if (success) {
      parts.push(`## Entry Deleted\n`);
      parts.push(`- **ID**: ${entry?.id}`);
      if (entry?.title) parts.push(`- **Title**: ${entry.title}`);
      parts.push(`- **Location**: ${entry?.location || 'unknown'}`);
    }

    return parts.join('\n');
  }

  /**
   * Render error
   */
  renderError() {
    const { message } = this.data;
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: 'error'
    }));

    parts.push(`## Error\n`);
    parts.push(message || 'An unknown error occurred');

    return parts.join('\n');
  }

  /**
   * Generic fallback renderer
   */
  renderGeneric() {
    const parts = [];

    parts.push(this.buildFrontmatter({
      type: this.data.type || 'unknown'
    }));

    // Just dump the data as formatted content
    parts.push('```json');
    parts.push(JSON.stringify(this.data, null, 2));
    parts.push('```');

    return parts.join('\n');
  }
}

module.exports = { MarkdownRenderer };
