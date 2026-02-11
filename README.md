# Sparko API

**Tagline:** 5 minutes a day to stay intellectually alive.

Sparko is a backend API for an iOS app that delivers daily cross-domain research sparks. It helps users discover research papers that are "not too close, not too far" from their interests, fostering intellectual curiosity.

## 🚀 Features

- **Research Interest Embedding**: Converts user research interests into vector embeddings using a local Python microservice (managed by the Ruby app).
- **Paper Recommendation**: Fetches and filters papers from arXiv based on embeddings.
- **Journal Discovery**: Provides a curated list of top-tier journals across various domains.
- **iOS-First Design**: API responses formatted for easy consumption by Swift/SwiftUI clients.

## 🛠 Tech Stack

- **Language**: Ruby 3.4.5
- **Web Framework**: Roda
- **Database**: 
  - Development/Test: SQLite3
  - Production: PostgreSQL
- **Background Jobs**: Shoryuken (AWS SQS)
- **ML/Embeddings**: Python 3.11 + Sentence Transformers (all-MiniLM-L6-v2)

## 📦 Setup & Installation

### Prerequisites
- Ruby 3.4.5 (managed via `rbenv` recommended)
- Python 3.11+
- Bundler (`gem install bundler`)

### Local Development

1. **Clone the repo**
   ```bash
   git clone <repo-url>
   cd Sparko-api
   ```

2. **Install Ruby Dependencies**
   ```bash
   bundle install
   ```

3. **Setup Python Environment**
   The app uses a Python script for embeddings.
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

4. **Configuration**
   Copy the example secrets file and edit it.
   ```bash
   cp config/secrets_example.yml config/secrets.yml
   ```
   *Note: You will need AWS credentials for SQS if working on background jobs, or ensure local fallbacks are configured.*

5. **Initialize Database**
   ```bash
   rake db:migrate
   ```

6. **Fetch Initial Data (Optional)**
   ```bash
   ruby bin/fetch_arxiv_papers.rb
   ```

7. **Run the Server**
   ```bash
   rake run
   ```
   The API will be available at `http://localhost:9292`.

## 🧪 Testing

Run the full test suite:
```bash
RACK_ENV=test bundle exec rake spec
```

Run code quality checks:
```bash
bundle exec rake quality:all
```

## 🌍 Deployment

### Railway (Recommended)
This project is configured for Railway using `nixpacks.toml` to handle the multi-language (Ruby + Python) environment.

1. Connect your GitHub repo to Railway.
2. Railway should auto-detect the `nixpacks.toml` configuration.
3. Set the required Environment Variables in the Railway dashboard:
   - `RACK_ENV`: `production`
   - `PIDFILE`: `./server.pid` (optional)
   - `SQS_QUEUE_NAME`: `sparko-research-interest-prod`
   - `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY` (for SQS)
   - `SESSION_SECRET`: (generate one with `rake new_session_secret`)

### Render
A `render.yaml` file is included for deploying as a Web Service + Worker.

## 📡 API Routes

### General
- `GET /`: Health check (200 OK)

### Research Interests
- `POST /api/v1/research_interest`: Submit a new interest term.
- `GET /api/v1/research_interest/{job_id}`: Check status of background embedding job.

### Papers
- `GET /api/v1/papers`: List papers (filterable by `journals[]` and `page`).

### Journals
- `GET /api/v1/journals`: List supported journals and domains.

---
*Built for the Sparko iOS App.*