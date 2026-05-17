# LLM Coding Challenge - Mobile UI Playground

This challenge is designed to understand how you use LLMs as development partners — to code faster, reason better, and improve the quality and flexibility of what you build.

You are expected to use tools like Cursor, Claude Code, or Gemini Code Assist for this coding challenge. We are just as interested in how you work with LLMs as we are in what you produce.

Please record up to 30 minutes of your development process — any moments that show how you think, prompt, debug, or experiment. No need to narrate or polish anything. Just a raw glimpse into your process is more than enough.

## What you will build

You will create a small mobile playground where users can update the UI using natural language commands. The app should interpret these prompts into structured layout instructions and apply them dynamically.

We have intentionally left the canvas open. You are free to choose the layout and design as long as there are a few components that clearly respond to user commands. A profile card, a form, a dashboard — any of these are a great starting point.

Example:

<img width="400" height="266" alt="mobile_blue_green" src="https://gist.github.com/user-attachments/assets/2b653acd-15b2-4258-84e5-c6f41711dcca" />

This is just a simple example to show the idea. Feel free to take it further, get creative, and push the interaction in ways that showcase your skills. Just aim for a reasonable scope — something that takes hours, not days.

## Key Tasks
- Design a mobile UI with a title, background, and modifiable components
- Include an input bar where users can prompt UI changes
- Convert user prompts into structured layout instructions
- Dynamically apply those instructions to update the UI in real time
- Support a reset command that reverts the UI to its initial state

Your playground should support 3 to 5 different prompt examples that trigger clear and visible changes.

## Prompt Handling

You may handle prompt interpretation in one of two ways:

### Option 1: Mocked (Required)
- Define the example prompts
- Create hardcoded JSON payloads
- Return the matching payload when a user enters one of the supported prompts

### Option 2: LLM-powered (Bonus)
- Use an LLM (e.g., OpenAI API, Gemini, local model) to generate structured output from user input
- Parse the model’s response and apply changes to the UI dynamically

Note: Real LLM integration is optional. But if you are enjoying the build and you have access to the necessary resources, feel free to go for it.

## Evaluation Criteria
- UI clarity: Are changes visually clear, immediate, and easy to interpret?
- Instruction design: Is the layout instruction format structured, readable, and easy to extend?
- Real-time updates: Do UI changes feel smooth and responsive?
- Code structure: Is the code modular, readable, and logically organized?
- LLM collaboration: Is there clear evidence of LLMs being used to build, debug, or reason?
- Creative energy: Does the work show expressiveness, curiosity, or unexpected ideas?