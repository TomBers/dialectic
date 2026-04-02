# RationalGrid

**AI-powered knowledge mapping for deeper thinking**

RationalGrid is an open-source web application that transforms how people explore ideas, engage with arguments, and build shared understanding. It combines Large Language Models with interactive graph visualization to enable active learning and critical thinking.

## What is RationalGrid?

RationalGrid is a knowledge mapping platform where:

- **Every question or statement becomes a node** in an interactive graph
- **AI responses branch out** in multiple directions, creating personalized knowledge maps
- **Ideas are structured visually**, revealing connections and relationships
- **Grids can be shared, explored, and built collaboratively**

Instead of linear chat conversations that disappear, RationalGrid creates persistent, explorable maps of interconnected ideas.

## Key Features

### 🌐 Interactive Knowledge Graphs
- **Node-based exploration**: Each response becomes a visual node in your knowledge grid
- **Non-linear thinking**: Branch conversations in multiple directions simultaneously
- **Visual relationships**: See how ideas connect and influence each other

### 🎯 Multiple Views
- **Graph View**: Interactive network visualization with pan, zoom, and exploration
- **Linear View**: Traditional thread-like reading experience
- **Presentation Mode**: Create and share slide decks from selected nodes

### ✨ AI-Powered Features
- **Multiple prompt modes**: University, Socratic, ELI5, Devil's Advocate, and more
- **Smart suggestions**: AI recommends related concepts and follow-up questions
- **Automatic categorization**: Generated tags help organize and discover content

### 📝 Rich Annotations
- **Text highlighting**: Select and annotate specific passages
- **Linked highlights**: Connect highlights to other nodes as evidence or questions
- **Collaborative notes**: Share insights and build on others' observations

### 👥 Community & Sharing
- **Public grids**: Share your knowledge maps with the world
- **User profiles**: Discover grids created by others
- **Curated content**: Featured and community-recommended explorations

## Technology Stack

RationalGrid is built with:

- **[Phoenix Framework](https://www.phoenixframework.org/)** (v1.7) - Modern Elixir web framework
- **[Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)** (v1.0) - Real-time, interactive UI without JavaScript frameworks
- **[PostgreSQL](https://www.postgresql.org/)** - Primary database
- **[Oban](https://github.com/sorentwo/oban)** - Background job processing
- **[req_llm](https://github.com/saleiva/req_llm)** - LLM integration for AI features
- **[Tailwind CSS](https://tailwindcss.com/)** - Utility-first styling


## Getting Started

### Prerequisites

- **Elixir 1.14+** and **Erlang/OTP 25+**
- **PostgreSQL 14+**
- **Node.js 18+** (for asset compilation)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/TomBers/rationalgrid.git
   cd rationalgrid
   ```

2. **Install dependencies**
   ```bash
   mix setup
   ```
   This command will:
   - Install Elixir dependencies
   - Create and migrate the database
   - Install and build frontend assets

3. **Configure environment variables**
     
   Required variables:
   - `DATABASE_URL` - PostgreSQL connection string
   - `SECRET_KEY_BASE` - Phoenix secret (generate with `mix phx.gen.secret`)
   - `LLM_API_KEY` - Your LLM provider API key
   - `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (optional, for OAuth)

4. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

5. **Visit** [`localhost:4000`](http://localhost:4000) in your browser

### Development

- **Run tests**: `mix test`
- **Format code**: `mix format`
- **Pre-commit checks**: `mix precommit` (runs formatter and tests)
- **Interactive console**: `iex -S mix phx.server`

## Project Structure

```
dialectic/
├── lib/
│   ├── dialectic/           # Core business logic
│   │   ├── accounts/        # User authentication & management
│   │   ├── graph/           # Graph data structures & operations
│   │   ├── highlights/      # Text annotation system
│   │   ├── llm/             # LLM integration & prompts
│   │   └── workers/         # Background job workers
│   └── dialectic_web/       # Web interface
│       ├── live/            # LiveView modules
│       ├── components/      # Reusable UI components
│       └── controllers/     # HTTP controllers
├── assets/                  # Frontend assets (CSS, JS)
├── priv/
│   ├── repo/migrations/     # Database migrations
│   └── static/              # Static files
└── test/                    # Test files
```

## Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation, your help makes RationalGrid better.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run `mix precommit` to ensure code quality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Deployment

RationalGrid can be deployed to any platform that supports Elixir/Phoenix applications. See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

Recommended platforms:
- [Fly.io](https://fly.io) - Built-in support with `fly.toml`
- [Render](https://render.com)
- [Gigalixir](https://www.gigalixir.com/)

## License

[Add your license here]

## Learn More About Phoenix

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Contact

- **Website**: [rationalgrid.com](https://rationalgrid.com) (if applicable)
- **Issues**: [GitHub Issues](https://github.com/yourusername/rationalgrid/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/rationalgrid/discussions)

---

Built with ❤️ to improve public understanding and learning through AI-powered knowledge mapping.
