import turicreate as tc

sf =  tc.SFrame('train.sframe')
groundTruthImages = sf['image_with_ground_truth']
groundTruthImages[0].show()