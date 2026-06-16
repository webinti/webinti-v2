import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    client: z.string(),
    summary: z.string(),
    stack: z.array(z.string()).default([]),
    category: z.enum(['web', 'mobile', 'ia', 'marketplace', 'crm', 'saas']),
    cover: z.string().optional(),
    url: z.string().url().optional(),
    year: z.number().int().min(2015).max(2100),
    duration: z.string().optional(),
    featured: z.boolean().default(false),
    order: z.number().default(100),
  }),
});

export const collections = { projects };
