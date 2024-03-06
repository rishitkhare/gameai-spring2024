import tensorflow as tf

# instantiate a model here

model = 0
#def init_if_necessary()
#    if model == 0:
#        return tf.keras.models.load_model("mymodel.keras")
#    return model

#def transmute(row):
#    return 7

def get_best_choice(row_of_data):
    # you write ALL YOUR CODE so it reports a number here
    # this can obviously call other functions
    # print(row_of_data)
#
#    model = init_if_necessary()
#    y_pred = model.predict(transmute(row_of_data))
#    choice = y_pred[0]
    
    # transmute the row into something your tensorflow model can use
    # ask the model for the response in some way that generates a number
    # return this number
    return ord(row_of_data[0][0])
