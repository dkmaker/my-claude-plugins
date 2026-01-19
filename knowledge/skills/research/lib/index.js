#!/usr/bin/env node

const { getProvider, listProviders } = require('./providers');
const profiles = require('./profiles.json');
const { initStorage } = require('./storage');
const { createEntry, saveEntry, getUnsavedEntries, getLibraryEntries, curateEntry, getEntryById, deleteEntry } = require('./storage/entries');
const { createCategory, getCategories, getCategoryById } = require('./storage/categories');
const { getRenderer } = require('./renderers');

/**
 * Parse command line arguments
 * @param {string[]} args - Process arguments (without node and script)
 * @returns {Object} Parsed options and query
 */
function parseArgs(args) {
  // Smart default: use AI format when running inside Claude Code
  const defaultFormat = process.env.CLAUDECODE === '1' ? 'ai' : 'md';

  const result = {
    profile: 'general',
    format: defaultFormat,
    query: null,
    listProfiles: false,
    listProviders: false,
    listCategories: false,
    createCategory: false,
    listUnsaved: false,
    listLibrary: false,
    curateId: null,
    viewId: null,
    deleteId: null,
    categoryId: null,
    categoryDesc: null,
    categoryRules: null,
    local: false,
    general: false,
    showThinking: false,
    help: false,
    options: {}
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];

    // Handle --key=value syntax
    if (arg.includes('=')) {
      const [key, value] = arg.split('=');
      if (key === '--format' || key === '-f') {
        result.format = value;
        i++;
        continue;
      } else if (key === '--profile' || key === '-p') {
        result.profile = value;
        i++;
        continue;
      }
    }

    if (arg === '--profile' || arg === '-p') {
      result.profile = args[++i];
    } else if (arg === '--format' || arg === '-f') {
      result.format = args[++i];
    } else if (arg === '--json') {
      result.format = 'json';
    } else if (arg === '--list-profiles') {
      result.listProfiles = true;
    } else if (arg === '--list-providers') {
      result.listProviders = true;
    } else if (arg === '--categories') {
      result.listCategories = true;
    } else if (arg === '--create-category') {
      result.createCategory = true;
    } else if (arg === '--category-desc') {
      result.categoryDesc = args[++i];
    } else if (arg === '--category-rules') {
      result.categoryRules = args[++i];
    } else if (arg === '--unsaved') {
      result.listUnsaved = true;
    } else if (arg === '--library') {
      result.listLibrary = true;
    } else if (arg === '--curate') {
      result.curateId = args[++i];
    } else if (arg === '--view' || arg === '--get') {
      result.viewId = args[++i];
    } else if (arg === '--delete') {
      result.deleteId = args[++i];
    } else if (arg === '--category') {
      result.categoryId = args[++i];
    } else if (arg === '--local') {
      result.local = true;
    } else if (arg === '--general') {
      result.general = true;
    } else if (arg === '--show-thinking') {
      result.showThinking = true;
    } else if (arg === '--help' || arg === '-h') {
      result.help = true;
    } else if (arg === '--model' || arg === '-m') {
      result.options.model = args[++i];
    } else if (arg === '--recency') {
      result.options.search_recency_filter = args[++i];
    } else if (arg === '--domains') {
      result.options.search_domain_filter = args[++i].split(',');
    } else if (arg === '--max-tokens') {
      result.options.max_tokens = parseInt(args[++i], 10);
    } else if (arg === '--temperature') {
      result.options.temperature = parseFloat(args[++i]);
    } else if (!arg.startsWith('-')) {
      // Collect remaining args as query
      result.query = args.slice(i).join(' ');
      break;
    }
    i++;
  }

  return result;
}

/**
 * Get help data
 * @returns {Object} Help data object
 */
function getHelpData() {
  return {
    type: 'help',
    content: `research-cli - Profile-based research interface for AI agents

Usage:
  research [options] <query>

Profiles:
  general       General-purpose research (default)
  code          Code examples and implementations
  docs          Official documentation and API references
  troubleshoot  Errors, bugs, and debugging solutions

Research Options:
  --profile, -p <name>   Use named profile (default: "general")
  --format, -f <format>  Output format: md, json, ai (default: ai if CLAUDECODE=1, else md)
  --model, -m <model>    Override model from profile
  --recency <period>     Filter by recency: day, week, month, year
  --domains <list>       Comma-separated domain filter
  --max-tokens <n>       Maximum response tokens
  --json                 Alias for --format=json
  --show-thinking        Display reasoning process (for reasoning models)
  --general              Save as general (not bound to current repo)

Storage Commands:
  --categories           List all categories
  --create-category      Create a new category
  --category-desc <d>    Description for --create-category
  --category-rules <r>   Rules for --create-category
  --unsaved              List unsaved entries
  --library              List curated library entries
  --view <id>            View full entry content by ID
  --curate <id>          Move entry to library (requires --category)
  --delete <id>          Delete an entry by ID
  --category <id>        Specify category for --curate or filter --library
  --local                Filter to current repository only

Info:
  --list-profiles        List available profiles
  --list-providers       List available providers
  --help, -h             Show this help

Examples:
  research "What is quantum computing?"
  research --profile code "React hooks examples"
  research --profile troubleshoot "ECONNREFUSED error"
  research --format=json "query"
  research --categories
  research --unsaved --local
  research --view <entry-id>
  research --curate <entry-id> --category <category-id>
  research --delete <entry-id>

Environment:
  PERPLEXITY_API_KEY     Required for Perplexity provider
  KNOWLEDGE_DATA_DIR     Override storage directory (default: ~/.local/share/knowledge)`
  };
}

/**
 * Get profiles data
 * @returns {Object} Profiles data object
 */
function getProfilesData() {
  const profilesList = Object.entries(profiles).map(([name, profile]) => ({
    name,
    description: profile.description,
    model: profile.model,
    provider: profile.provider
  }));

  return {
    type: 'profiles',
    defaultProfile: 'general',
    profiles: profilesList
  };
}

/**
 * Get providers data
 * @returns {Object} Providers data object
 */
function getProvidersData() {
  return {
    type: 'providers',
    providers: listProviders()
  };
}

/**
 * Get categories data
 * @returns {Object} Categories data object
 */
function getCategoriesData() {
  return {
    type: 'categories',
    categories: getCategories()
  };
}

/**
 * Get entries data
 * @param {Array} entries - List of entries
 * @param {string} title - Title for the list
 * @returns {Object} Entries data object
 */
function getEntriesData(entries, title) {
  return {
    type: 'entries',
    title,
    count: entries.length,
    entries
  };
}

/**
 * Handle category creation
 * @param {Object} args - Parsed arguments
 * @returns {Object} Result data object
 */
function handleCreateCategory(args) {
  if (!args.query) {
    return {
      type: 'error',
      message: 'Usage: --create-category <slug> [--category-desc "description"] [--category-rules "rules"]\nExample: --create-category react-patterns'
    };
  }

  const slug = args.query.split(' ')[0];
  const description = args.categoryDesc || `Category for ${slug}`;
  const rules = args.categoryRules || '';

  try {
    const category = createCategory({ slug, description, rules });
    return {
      type: 'create-category',
      success: true,
      category
    };
  } catch (error) {
    return {
      type: 'error',
      message: error.message
    };
  }
}

/**
 * Handle curating an entry
 * @param {string} entryId - Entry ID to curate
 * @param {string} categoryId - Category ID to move to
 * @returns {Object} Result data object
 */
function handleCurate(entryId, categoryId) {
  if (!categoryId) {
    return {
      type: 'error',
      message: 'Error: --curate requires --category <category-id>'
    };
  }

  const category = getCategoryById(categoryId);
  if (!category) {
    return {
      type: 'error',
      message: `Error: Category not found: ${categoryId}\nUse --categories to list available categories`
    };
  }

  const entry = curateEntry(entryId, categoryId);
  if (!entry) {
    return {
      type: 'error',
      message: `Error: Entry not found in unsaved: ${entryId}`
    };
  }

  return {
    type: 'curate',
    success: true,
    entry,
    category
  };
}

/**
 * Handle viewing an entry
 * @param {string} entryId - Entry ID to view
 * @returns {Object} Result data object
 */
function handleView(entryId) {
  const entry = getEntryById(entryId);
  if (!entry) {
    return {
      type: 'error',
      message: `Error: Entry not found: ${entryId}`
    };
  }

  return {
    type: 'entry',
    entry
  };
}

/**
 * Handle deleting an entry
 * @param {string} entryId - Entry ID to delete
 * @returns {Object} Result data object
 */
function handleDelete(entryId) {
  const entry = getEntryById(entryId);
  if (!entry) {
    return {
      type: 'error',
      message: `Error: Entry not found: ${entryId}`
    };
  }

  const deleted = deleteEntry(entryId);
  if (!deleted) {
    return {
      type: 'error',
      message: `Error: Failed to delete entry: ${entryId}`
    };
  }

  return {
    type: 'delete',
    success: true,
    entry
  };
}

/**
 * Execute a research query
 * @param {Object} args - Parsed arguments
 * @returns {Promise<Object>} Research result data object
 */
async function executeQuery(args) {
  // Load profile
  const profile = profiles[args.profile];
  if (!profile) {
    return {
      type: 'error',
      message: `Error: Unknown profile "${args.profile}"\nAvailable profiles: ${Object.keys(profiles).join(', ')}`
    };
  }

  // Get provider
  const Provider = getProvider(profile.provider);
  if (!Provider) {
    return {
      type: 'error',
      message: `Error: Unknown provider "${profile.provider}"`
    };
  }

  if (!Provider.isAvailable()) {
    return {
      type: 'error',
      message: `Error: ${Provider.displayName} not configured\nSet the ${Provider.envKey} environment variable`
    };
  }

  // Merge profile options with CLI options
  const options = {
    ...profile.options,
    model: args.options.model || profile.model,
    ...args.options
  };

  // Create provider and execute query
  const provider = new Provider(options);
  const result = await provider.ask(args.query, options);

  // Always save to storage
  const entry = createEntry(result, {
    profile: args.profile,
    general: args.general,
    cwd: process.cwd()
  });
  saveEntry(entry);

  return {
    type: 'research',
    provider: result.provider,
    model: result.model,
    profile: args.profile,
    tokens: result.usage?.total_tokens,
    saved: true,
    title: result.title,
    content: result.content || result.answer,
    thinking: result.thinking,
    examples: result.examples,
    sources: result.sources
  };
}

/**
 * Main entry point
 */
async function main() {
  // Initialize storage on startup
  initStorage();

  const args = parseArgs(process.argv.slice(2));

  let data;
  try {
    if (args.help) {
      data = getHelpData();
    } else if (args.listProfiles) {
      data = getProfilesData();
    } else if (args.listProviders) {
      data = getProvidersData();
    } else if (args.listCategories) {
      data = getCategoriesData();
    } else if (args.createCategory) {
      data = handleCreateCategory(args);
    } else if (args.listUnsaved) {
      data = getEntriesData(getUnsavedEntries({ local: args.local }), 'Unsaved');
    } else if (args.listLibrary) {
      data = getEntriesData(getLibraryEntries({ categoryId: args.categoryId, local: args.local }), 'Library');
    } else if (args.curateId) {
      data = handleCurate(args.curateId, args.categoryId);
    } else if (args.viewId) {
      data = handleView(args.viewId);
    } else if (args.deleteId) {
      data = handleDelete(args.deleteId);
    } else if (!args.query) {
      data = {
        type: 'error',
        message: 'Error: No query provided\n\nRun with --help for usage information'
      };
    } else {
      data = await executeQuery(args);
    }
  } catch (error) {
    data = {
      type: 'error',
      message: `Error: ${error.message}`
    };
  }

  const renderer = getRenderer(args.format, data, { showThinking: args.showThinking });
  console.log(renderer.render());

  if (data.type === 'error') {
    process.exit(1);
  }
}

main();
