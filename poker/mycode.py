import tensorflow as tf
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

# instantiate a model here

model = 0

last_chips = -1

#def init_if_necessary()
#    if model == 0:
#        return tf.keras.models.load_model("mymodel.keras")
#    return model

#def transmute(row):
#    return 7

class Card:
    def __init__(self, suit, value) -> None:
        self.suit = {'spade': 1, 'club': 2, 'diamond': 3, 'heart': 4}[suit]
        self.value = int(value)

    def get_X_vector(self):
        return [self.suit, self.value]

empty_card = Card('spade', 0)
empty_card.suit = 0


class Player:
    def __init__(self, bet, folded, chips, cards):
        self.bet = bet; assert type(bet) is int; assert bet >= 0
        self.folded = 1 if folded == 'True' else 0; assert type(folded) is str
        self.chips = chips; assert type(chips) is int; assert chips >= 0
        self.cards = cards

        assert type(cards) is list
        for card in cards:
            assert type(card) is Card

    def get_X_vector(self):
        output = [self.bet, self.folded, self.chips]
        for card in self.cards:
            output.extend(card.get_X_vector())
        for _ in range(4 - len(self.cards)):
            output.extend(empty_card.get_X_vector())
        return output

def get_additional_x_vector(player_card, hand_value):
    return player_card.get_X_vector() + [hand_value]



def get_X_vector(row_of_data):
    """Takes the data as passed by the game and formats it"""
    
    # figure out who I am: p4
    # sort the rest based on name.
    # p1, p2, p3

    # for each player:
    # for each cards:
        # create Card() and add to card_list
    # create Player(..., card_list)
    # players.append(above obj)
    
    # do the same for p4: me
    # more = get_additional_x_vector(p4.cards, p4.hand_value)


    # return [p1.get_X_vector(), p2.get_X_vector(), p3.get_X_vector(), p4.get_X_vector()] + more
    # or something like this (flatten the list)
    

    players_unsorted = []
    my_player = -1

    for data in row_of_data:
        if(type(data) is dict):
            # Throw away metadata like timestamp
            if("round_winner_by_cards" in data):
                my_player = data
            else:
                players_unsorted.append(data)
    
    players = sorted( players_unsorted, key=lambda player: str.casefold( player["name"] ) )

    for player in players:
            cards = []
            for card in player["face_up_cards"]:
                card_rank = {'1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10, 'jack': 11, 'queen': 12, 'king': 13}[card[0]]
                cards.append(Card(value=card_rank, suit=card[1]))
            
            p = Player(folded=player["folded"], chips=player["chips"], cards=cards)

    my_cards = []
    for card in my_player["face_up_cards"]:
        card_rank = {'1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10, 'jack': 11, 'queen': 12, 'king': 13}[card[0]]
        my_cards.append(Card(value=card_rank, suit=card[1]))
    
    my_p = my_player(folded=my_player["folded"], chips=player["chips"], cards=cards)


    my_player_extra_data = get_additional_x_vector(my_cards, my_player["handvalue"])

    return [players[0].get_X_vector(), players[1].get_X_vector(), players[2].get_X_vector(), my_player.get_X_vector()] + my_player_extra_data

        

def str_to_int(name):
    """Converts a string value to an associated integer"""
    encoded_str =  0
    for char in name:
        encoded_str += ord(char)
    return encoded_str

def append_cards(cards, output_list, max):
    """Takes a list of cards and returns a list of ints that represent each card"""
    for card in cards:
        output_list.append(str_to_int(card[0]))
        output_list.append(str_to_int(card[1]))
    for excess in range(max - len(cards)):
        output_list.extend([0, 0])

def parse_data(row_of_data):
    "Turns the data given by the program into a list of ints"
    X = []
    chips = -1
    for data in row_of_data:
        if(type(data) is dict):
            X.append(str_to_int(data["name"]))
            X.extend([data["bet"], int(data["folded"] == "True"), data["chips"]])
            append_cards(data["face_up_cards"], X, 4)
            if("round_winner_by_cards" in data):
                chips = data["chips"]
                X.append(str_to_int(data["round_winner_by_cards"]))
##CANNOT SEE                append_cards(data["face_down_cards"], X, 4)
                append_cards(data["face_player_cards"], X, 1)

                X.append(str_to_int(data["handvalue"]))
    temp_array = np.array(X, dtype = np.int32)
    return tf.convert_to_tensor(temp_array,dtype=tf.int32), chips
    


def get_best_choice(row_of_data):

    "Calculates the best choice"

    X, chips = parse_data(row_of_data)

    D = 58
    """
        if(last_chips == -1):
            chip_change = -1
        else:
            chip_change = last_chips - chips


        last_chips = chips

        if(chip_change != -1):
        process_change_in_chips


    """
    #options = -1, 0, "value from 0 to 1"

    print("\n\n\nINCOMING", tf.shape(X).numpy()[0], chips, X)

    #DATA TO PYTHON: ['04:34:57.558 PM 12-Mar-2024', 'VISIBLE', {'name': 'danny', 'bet': 0.0, 'folded': 'True', 'chips': 0.0, 'face_up_cards': []}, {'name': 'elissa', 'bet': 1.0, 'folded': 'False', 'chips': 27.0, 'face_up_cards': [['9', 'diamond'], ['3', 'diamond']]}, {'name': 'alice', 'bet': 1.0, 'folded': 'False', 'chips': 27.0, 'face_up_cards': [['7', 'spade'], ['10', 'club']], 'round_winner_by_cards': 'elissa', 'face_down_cards': [['jack', 'spade'], ['8', 'spade']], 'face_player_cards': [['5', 'spade']], 'all_cards': [['7', 'spade'], ['8', 'spade'], ['10', 'club'], ['5', 'spade'], ['jack', 'spade']], 'handvalue': 'high card'}]

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

def build_model():

    """
    Still in the work, builds the model based off of the data
    """

    foo = tf.keras.models.load_model('my_model.keras')
    foo.summary()

    x = pd.read_csv("./x.csv")
    y = pd.read_csv("./y.csv")
    x_train, x_test, y_train, y_test = train_test_split(x.to_numpy(), y.to_numpy(), test_size=0.33)

    model = tf.keras.models.Sequential([
        tf.keras.layers.Dense(64),
        # tf.keras.layers.Dense(128),
        # tf.keras.layers.Dense(256),
        # tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dense(256, activation='relu'),
        # tf.keras.layers.Dropout(0.1),
        tf.keras.layers.Dense(2)
    ])

    loss_fn = tf.keras.losses.MeanAbsoluteError() #BinaryFocalCrossentropy(from_logits=True)
    model.compile(optimizer='adam',
                loss=loss_fn,
                metrics=tf.keras.metrics.MeanSquaredError())
    
    model.fit(x_train, y_train, epochs=100)

    model.evaluate(x_test,  y_test, verbose=2)
    model.save("my_model.keras")

    print("SUMMARY", model.summary())