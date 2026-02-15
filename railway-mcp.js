#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fetch from "node-fetch";

const token = process.env.RAILWAY_TOKEN;

async function gql(query, variables = {}) {
  if (!token) {
    throw new Error("RAILWAY_TOKEN env var required");
  }

  const res = await fetch("https://backboard.railway.app/graphql/v2", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!res.ok) {
    throw new Error(`Railway API HTTP ${res.status}`);
  }

  const json = await res.json();
  if (json.errors) {
    throw new Error(JSON.stringify(json.errors));
  }
  return json.data;
}

const server = new McpServer({
  name: "railway-mcp",
  version: "1.0.0",
});

server.tool("railway.services", "List Railway projects and services", {}, async () => {
  const data = await gql(
    `query {
      me {
        projects {
          edges {
            node {
              id
              name
              services {
                edges {
                  node {
                    id
                    name
                  }
                }
              }
            }
          }
        }
      }
    }`
  );

  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
});

server.tool(
  "railway.deploy",
  "Trigger deploy for a Railway service ID",
  { serviceId: z.string().min(1) },
  async ({ serviceId }) => {
    const data = await gql(
      `mutation($serviceId: String!) {
        deployService(serviceId: $serviceId, input: {}) {
          id
          status
        }
      }`,
      { serviceId }
    );

    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "railway.logs",
  "Fetch recent deployment logs for a Railway service ID",
  { serviceId: z.string().min(1), limit: z.number().int().positive().max(500).optional() },
  async ({ serviceId, limit = 50 }) => {
    const data = await gql(
      `query($serviceId: String!, $limit: Int) {
        service(id: $serviceId) {
          deployments(last: $limit) {
            edges {
              node {
                id
                status
                createdAt
                logs
              }
            }
          }
        }
      }`,
      { serviceId, limit }
    );

    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
