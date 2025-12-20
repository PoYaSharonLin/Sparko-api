release: rake db:migrate && PATH="/app/.venv/bin:$PATH" ruby bin/fetch_arxiv_papers.rb
web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}
worker: bundle exec shoryuken -R -C config/shoryuken.yml
embed: EMBED_DEVICE=cpu ./.venv/bin/python -m gunicorn -w 1 -k gthread --threads 8 -b 0.0.0.0:8001 app.domain.clustering.services.embed_service:app
