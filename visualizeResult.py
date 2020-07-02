import coremltools
from os.path import dirname, join as pjoin
from os import remove
from PIL import Image
import turicreate as tc
from resizeimage import resizeimage
from collections import namedtuple

# Load the model
mlmodel = coremltools.models.MLModel('Hands.mlmodel')
# Select one of the files from the test data
test_data =  tc.SFrame('test.sframe')
testImagePath = test_data[0]['path']
# Resize according to network input image shpae
Size = namedtuple('Size', ['width', 'height'])
inputImageSize = Size(width = 416, height = 416)
testImageOrig = Image.open(testImagePath)
resized = resizeimage.resize_thumbnail(testImageOrig, inputImageSize, Image.LINEAR)
scaleFactor = max(testImageOrig.width / inputImageSize.width, testImageOrig.height / inputImageSize.height)
testImageResized = Image.new('RGB', inputImageSize, (255, 255, 255))
testImageResized.paste(resized, (0, 0))

testImageResizedPath = 'tempImage.jpg'
testImageResized.save(testImageResizedPath)

# Inferring
predictions = mlmodel.predict({'image': testImageResized})
annotations = []
for idx, coordinate in enumerate(predictions['coordinates']):
    confidences = predictions['confidence'][idx]
    label = 'right' if confidences[0] > confidences[1] else 'left'
    x = coordinate[0] * inputImageSize[0] * scaleFactor
    y = coordinate[1] * inputImageSize[1]  * scaleFactor
    width = coordinate[2] * inputImageSize[0] * scaleFactor
    height = coordinate[3] * inputImageSize[1] * scaleFactor
    annotationCoordinates = { 'x': x, 'y': y, 'width': width, 'height': height}
    annotations.append({ 'confidence': max(confidences), 'coordinates': annotationCoordinates, 'label': label })

tcTestImageOrig = tc.Image(testImagePath)
annotatedImage = tc.object_detector.util.draw_bounding_boxes(tcTestImageOrig, annotations)
annotatedImage.show()

# Inferring using original Darknet-YOLO model
handsModel = tc.load_model('Hands')
tcTestImageResized = tc.Image(testImageResizedPath)
tcPredictions = handsModel.predict(tcTestImageResized)

# Do scaling to show bounding boxes on an original image
for idx, prediction in enumerate(tcPredictions):
    coordinates = prediction['coordinates']
    coordinates['x'] *= scaleFactor
    coordinates['y'] *= scaleFactor
    coordinates['width'] *= scaleFactor
    coordinates['height'] *= scaleFactor
annotatedImage = tc.object_detector.util.draw_bounding_boxes(tcTestImageOrig, tcPredictions)
annotatedImage.show()

remove(testImageResizedPath)