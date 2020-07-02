import turicreate as tc

# Inferring using original Darknet-YOLO model
handsModel = tc.load_model('Hands')
# Evaluate the model and save the results into a dictionary
test_data =  tc.SFrame('test.sframe')
metrics = handsModel.evaluate(test_data)
print(metrics)