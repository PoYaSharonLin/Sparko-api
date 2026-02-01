# Sparko API

**Tagline:** 5 minutes a day to stay intellectually alive.

Sparko is a backend API for an iOS app that delivers daily cross-domain research sparks. Users receive one research paper recommendation per day, designed to be "not too close, not too far" from their interests.

## Routes

### Root check
`GET /`

Status: 
- 200: API server runs 

### Research Interest 
`POST /api/v1/research_interest`

Status:
- 201: research interest created successfully
- 400: invalid research interest input

Example:
```bash
curl -X POST http://localhost:9292/api/v1/research_interest \
     -H "Content-Type: application/json" \
     -d '{"term": "machine learning"}' \
     -w "\nHTTP Status: %{http_code}\n"

# {"term":"machine learning","vector_2d":{"x":-0.024392,"y":0.003244}}
# HTTP Status: 201
```

### Papers
`GET /api/v1/papers`

Status: 
- 200: papers retrieved successfully
- 400: invalid journal name input

Example:
```bash
curl "http://localhost:9292/api/v1/papers?journals%5B%5D=MIS+Quarterly&page=1" \
     -w "\nHTTP Status: %{http_code}\n"
```

---

## Setup

1. Copy `config/secrets_example.yml` to `config/secrets.yml` 
2. Ensure correct Ruby version (see `.ruby-version`)
3. Run `gem install bundler` 
4. Run `bundle install` 
5. Run `python3 -m venv .venv` 
6. Run `source .venv/bin/activate` 
7. Run `pip install -r requirements.txt` 
8. Run `ruby bin/fetch_arxiv_papers.rb` to fetch papers from arXiv
9. Run `rake run` to start the server

## Testing

```bash
RACK_ENV=test bundle exec rake spec
```

## Quality Checks

```bash
bundle exec rake quality:all
```