# frozen_string_literal: true
import sys
import json
import numpy as np
from sklearn.manifold import TSNE
from sklearn.decomposition import PCA


def reduce_dimension(embedding_data):
    """
    If a single embedding vector is provided, it returns the first two elements.
    If a list of vectors is provided, it reduces their dimension to 2 components.

    Args:
        embedding_data (list or list of lists): A high-dimensional vector
                                                or a list of high-dimensional vectors.

    Returns:
        list or list of lists: A 2-dimensional vector or a list of 2D vectors.
    """
    # Check empty input
    if not embedding_data:
        return []

    # Check if single vector
    if not isinstance(embedding_data[0], list):
        # return first 2 numbers
        return embedding_data[:2]

    # Check if list of vectors
    data = np.array(embedding_data)
    n_samples = data.shape[0]
    match n_samples:
        case 0:
            return []
        case 1:
            # Case for n_samples=1, return first 2 numbers 
            return [data[0][:2].tolist()]
        case n if n <= 5:
            # Case for n_samples=2~5, use PCA.
            pca = PCA(n_components=2)
            return pca.fit_transform(data).tolist()
        case _:
            # Case for n_samples>5, use t-SNE.
            perplexity_value = min(30, n_samples - 1)
            tsne = TSNE(n_components=2, perplexity=perplexity_value,
                        max_iter=1000, random_state=42,
                        init='pca', learning_rate='auto')
            return tsne.fit_transform(data).tolist()


if __name__ == "__main__":
    try:
        input_data = sys.stdin.read()
        embedding = json.loads(input_data)
        two_d_embedding = reduce_dimension(embedding)
        print(json.dumps(two_d_embedding))
    except json.JSONDecodeError as error:
        sys.stderr.write(f"Error decoding JSON: {error}\n")
        sys.exit(1)
    except Exception as error:
        sys.stderr.write(f"An unexpected error occurred: {error}\n")
        sys.exit(1)
