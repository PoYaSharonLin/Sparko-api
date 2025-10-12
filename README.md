# AcaRadar 
Application that allows researchers to find innovative research topics from other domains. 


## Overview
AcaRadar will pull data from arXiv's API to fetch title, summary, authors, publication date, and categories of research papers. 

It will then preprocess the text data and transform them into embeddings using pre-trained scientific language models. 

Finally, it will cluster the embeddings to identify research topics and visualize them in a word cloud showing 
1. The most frequent terms in selected domains
2. Intersections between different domains 

We hope this tool will give researchers a quick overview of research trends in their own and other domains, and inspire them to explore innovative research topics.

## Objectives
### Short-term usability goals
1. Preprocess text data and generate embeddings
2. Define n-gram frequency algo for word cloud 
3. Define clustering algo to define the distance between each n-gram 
4. Define intersection between different domains

### Long-term goals
1. Speed up the embedding generation process


### Setup

- Copy `config/secrets_example.yml` to `config/secrets.yml` 
- Ensure correct version of Ruby install (see .`ruby-version` for `rbenv`)
- Run `bundle install`

## Running tests
### To run tests:
```bash
rake spec
```

### To test code quality:
```bash
rake quality:all
```