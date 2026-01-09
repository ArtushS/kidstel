const String storyAgentUrl = String.fromEnvironment(
  'STORY_AGENT_URL',
  defaultValue: 'https://llm-generateitem-fjnopublia-uc.a.run.app',
);

const bool useMockStoryGeneration = bool.fromEnvironment(
  'USE_MOCK_STORIES',
  defaultValue: true,
);
