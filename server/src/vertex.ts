import { VertexAI } from '@google-cloud/vertexai';

export type GenerateOptions = {
  projectId: string;
  location: string;
  model: string;
};

export function createVertexModel(opts: GenerateOptions) {
  const vertex = new VertexAI({
    project: opts.projectId,
    location: opts.location,
  });

  // Uses Gemini models on Vertex AI.
  return vertex.getGenerativeModel({
    model: opts.model,
  });
}
