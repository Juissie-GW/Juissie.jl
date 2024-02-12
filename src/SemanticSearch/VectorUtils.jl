# VectorUtils.jl

module VectorUtils

using LinearAlgebra

"""
    cosine_similarity(vec1, vec2)

Calculates the cosine of the angle between two vectors.

Parameters
----------
vec1 : AbstractVector{T}
    the first vector
vec2 : AbstractVector{T}
    the second vector

Notes
-----
Should range from -1 to 1
Higher values = vectors are more cosine_similar
"""
function cosine_similarity(vec1, vec2)
    dot(vec1, vec2) / (norm(vec1) * norm(vec2))
end