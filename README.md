# AcaRadar Web API
Web API allows users to 
1. retrieve *research interest* and *research interest embeddings*
2. retrieve *papers* from *selected journals* to compute *similarity score*. 


## Routes
### Root check
`GET/`

status: 
- 200: API server runs 

### Retrieve research interest 
`POST /api/v1/research_interest`

Status
- 201: research interest created successfully
- 400: invalid research interest input

Example:
POST your research interest (this sets the session)
```bash
curl -X POST http://localhost:9292/api/v1/research_interest \
     -H "Content-Type: application/json" \
     -d '{"term": "machine learning"}' \
     --cookie-jar /tmp/acaradar_cookie.jar \
     -w "\nHTTP Status: %{http_code}\n" \
     --silent

# {"term":"machine learning","vector_2d":{"x":-0.024392,"y":0.003244}}
# HTTP Status: 201
```


### Retrieve papers
`GET /api/v1/papers`

Status: 
- 200: papers retrieved successfully
- 400: invalid journal name input

Example:
4. GET the papers — reusing the same session cookie
```bash
curl "http://localhost:9292/api/v1/papers?journals%5B%5D=MIS+Quarterly&journals%5B%5D=Management+Science&page=1"   --cookie /tmp/acaradar_cookie.jar -w "\nHTTP Status: %{http_code}\n"

# {"research_interest_term":"machine learning","research_interest_2d":[-0.024391869083046913,0.0032444987446069717],"journals":["MIS Quarterly","Management Science"],"papers":{"data":[{"origin_id":"http://arxiv.org/abs/1702.08072v1","title":"Knowledge Reuse for Customization: Metamodels in an Open Design Community for 3d Printing","abstract" ...
# ...
# "pdf_url":"https://arxiv.org/pdf/1108.4098v1","published_at":"2011-08-20T07:43:46+08:00","authors":"","similarity_score":null}]},"pagination":{"current":1,"total_pages":2,"total_count":15,"prev_page":null,"next_page":2}}
# HTTP Status: 200
```

---

## Setup

- Copy `config/secrets_example.yml` to `config/secrets.yml` 
- Ensure correct version of Ruby install (see .`ruby-version` for `rbenv`)
- Run `gem install bundler` to install bundler
- Run `bundle install` to install ruby dependencies
- Run `python3 -m venv .venv` to create a virtual environment
- Run `source .venv/bin/activate` to activate the virtual environment
- Run `python -m pip install -r requirements.txt` to install python dependencies
- Run `ruby bin/fetch_arxiv_papers.rb` to fetch papers from arXiv API and store them in the database
- Run `rake run` to run the application
