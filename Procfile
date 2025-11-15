release: rake db:migrate && ruby bin/fetch_arxiv_papers.rb
web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}