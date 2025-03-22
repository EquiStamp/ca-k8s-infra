from datetime import timedelta

from feast import Entity, Field, FeatureView, FileSource, ValueType
from feast.types import Float32, Int64

# Define an entity for the feature
user = Entity(name="user_id",  description="user id", join_keys=["user_id"])

# Define a data source for the features
file_source = FileSource(
    path="data/example_features.parquet",
    event_timestamp_column="event_timestamp",
)

# Define a feature view
example_features_view = FeatureView(
    name="example_features",
    entities=[user],
    ttl=timedelta(days=1),
    schema=[
        Field(name="feature_1", dtype=Float32),
        Field(name="feature_2", dtype=Int64),
    ],
    source=file_source,
)
