#!/usr/bin/env node
/**
 * Context7 - A Model Context Protocol (MCP) server for providing
 * up-to-date documentation and code examples to AI assistants.
 */

import { readFileSync } from 'fs';

// --- Documentation Sources ---
const documentationSources = {
  'google_generative_ai_dart': {
    name: 'google_generative_ai (Dart)',
    description: 'Get the documentation for the Google Generative AI Dart library.',
    url: 'https://pub.dev/documentation/google_generative_ai/latest/',
  },
  'flutter_riverpod': {
    name: 'flutter_riverpod',
    description: 'Get the documentation for the flutter_riverpod state management library.',
    url: 'https://riverpod.dev/docs/getting_started',
  },
  'google_generative_ai_python': {
    name: 'google-generativeai (Python)',
    description: 'Get the documentation for the Google Generative AI Python library.',
    url: 'https://ai.google.dev/api/python/google/generativeai',
  },
  'flask': {
    name: 'Flask',
    description: 'Get the documentation for the Flask web framework.',
    url: 'https://flask.palletsprojects.com/en/3.0.x/',
  },
  'http_dart': {
    name: 'http (Dart)',
    description: 'Get the documentation for the Dart http client library.',
    url: 'https://pub.dev/packages/http',
  },
  'flutter_tts': {
    name: 'flutter_tts',
    description: 'Get the documentation for the Flutter text-to-speech plugin.',
    url: 'https://pub.dev/packages/flutter_tts',
  },
  'shared_preferences': {
    name: 'shared_preferences',
    description: 'Get the documentation for the Flutter shared preferences plugin.',
    url: 'https://pub.dev/packages/shared_preferences',
  },
  'isar': {
    name: 'Isar Database',
    description: 'Get the documentation for the Isar NoSQL database for Flutter.',
    url: 'https://isar.dev/',
  },
  'firebase_flutter': {
    name: 'Firebase (Flutter)',
    description: 'Get the documentation for Firebase integration with Flutter.',
    url: 'https://firebase.google.com/docs/flutter/setup',
  },
  'flutter_svg': {
    name: 'flutter_svg',
    description: 'Get the documentation for the Flutter SVG rendering library.',
    url: 'https://pub.dev/packages/flutter_svg',
  },
  'flask_sqlalchemy': {
    name: 'Flask-SQLAlchemy',
    description: 'Get the documentation for Flask-SQLAlchemy.',
    url: 'https://flask-sqlalchemy.palletsprojects.com/en/3.1.x/',
  },
  'psycopg2_binary': {
    name: 'psycopg2-binary',
    description: 'Get the documentation for the Psycopg2 PostgreSQL adapter.',
    url: 'https://www.psycopg.org/docs/',
  },
  'celery': {
    name: 'Celery',
    description: 'Get the documentation for the Celery distributed task queue.',
    url: 'https://docs.celeryq.dev/en/stable/',
  },
  'stripe_python': {
    name: 'Stripe (Python)',
    description: 'Get the documentation for the Stripe Python library.',
    url: 'https://stripe.com/docs/api/python',
  },
  'flask_jwt_extended': {
    name: 'Flask-JWT-Extended',
    description: 'Get the documentation for Flask-JWT-Extended.',
    url: 'https://flask-jwt-extended.readthedocs.io/en/stable/',
  },
  'flask_limiter': {
    name: 'Flask-Limiter',
    description: 'Get the documentation for Flask-Limiter.',
    url: 'https://flask-limiter.readthedocs.io/en/stable/',
  },
};

// Read stdin for MCP protocol messages
const input = readFileSync(0, 'utf8');
const req = JSON.parse(input);
const { method, params, id } = req;

async function handle() {
  if (method === 'initialize') {
    return {
      id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {},
        },
        serverInfo: {
          name: 'context7-server',
          version: '1.0.0',
        },
      },
    };
  }

  if (method === 'tools/list') {
    const tools = Object.keys(documentationSources).map(toolName => {
      const source = documentationSources[toolName];
      return {
        name: toolName,
        description: source.description,
        inputSchema: {},
      };
    });

    return {
      id,
      result: {
        tools,
      },
    };
  }

  if (method === 'tools/call') {
    const { name } = params;

    try {
      if (!documentationSources[name]) {
        throw new Error(`Unknown tool: ${name}`);
      }

      const result = {
        url: documentationSources[name].url,
      };

      return {
        id,
        result: {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        },
      };
    } catch (error) {
      return {
        id,
        error: {
          code: -1,
          message: error.message,
        },
      };
    }
  }

  return {
    id,
    result: {},
  };
}

const response = await handle();
console.log(JSON.stringify(response));
