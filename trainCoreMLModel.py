import turicreate as tc

# Load the data
train =  tc.SFrame('train.sframe')
# Create a model
model = tc.object_detector.create(train, feature='image', max_iterations=15000)
model.save('Hands')
# Export for use in Core ML
model.export_coreml('Hands.mlmodel')