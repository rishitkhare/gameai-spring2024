import tensorflow as tf
from tensorflow import keras
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

class Card:
    def __init__(self, suit, value) -> None:
        self.suit = {'spade': 1, 'club': 2, 'diamond': 3, 'heart': 4}[suit]
        self.value = {0: 0, 'ace': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10, 'jack': 11, 'queen': 12, 'king': 13}[value]

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
    

# TODO: Change this from random choice to instead use model to make decision
def get_best_choice(row_of_data):
    import random
    return random.choice([0]*20 + [1]*5 + [2]*1 + [3]*1)

    """Calculates the best choice"""

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

def convert_training_data():
    training_data = ([], [])
    def emit(
        face_player_card, # state that only player knows
        face_up_cards, # state that everyone knows about player
        table_cards, # state of rest of the table.
        player_chips, # my chips
        action_taken, # action taken
        y_score # Y to learn: how much did this action contribute to the win/loss
    ):
        # for now, just use the cards that a player has
        cards = [Card(x[1], x[0]) for x in face_player_card + face_up_cards]
        player = Player(int(action_taken.bet), 'True' if action_taken.folded else 'False', int(player_chips), cards)
        training_data[0].append(player)
        training_data[1].append(y_score)


    # returns x, y
    import json
    with open('poker.jsonl', 'r') as file:
        data = file.readlines()
        data = list(filter(lambda x: len(x) > 0, (x.strip() for x in data)))
        data = [json.loads(x) for x in data]

    # Understanding the data
    # for x in data:
    #     players = x[2:]
    #     players.sort(key=lambda x: x['name'])
    #     print(x[1])
    #     for player in players:
    #         pcards = len(player.get('face_up_cards', []))
    #         print(f"Player: {player['name']}, Chips: {player.get('chips', -1)} Bet: {player.get('bet', -1)} Folded: {player.get('folded', -1)}, round_winner_by_cards: {player.get('round_winner_by_cards', '')}, #cards: {pcards}")

    # How often was a default value used for the number of chips won/lost. This happens when a game is reset.
    n_losers_default_picked = 0
    n_winner_default_picked = 0
    n_games = 0

    while True:
        # search for first reset
        i = next((i for i, x in enumerate(data) if x[1] == 'RESET'), None)
        if i is None:
            print('no more resets, so stopping even though there are %d lines left' % len(data))
            break

        chips = {}
        rst = data[i]
        for player in rst[2:]:
            chips[player['name']] = player['chips']

        from collections import namedtuple
        Action = namedtuple('Action', ['bet', 'folded'])
        last_actions = {name: Action(0.0, False) for name in chips.keys()} # important for it to be 0.0 and not 0, because the parsed default json value is 0.0

        # search for first WIN
        j = next((i for i, x in enumerate(data) if x[1] == 'WIN'), None)
        if j is None:
            print('no more wins, which is perhaps weird. stopping even though there are %d lines left' % len(data))
            break
        assert i < j, 'win happens before reset'
        game_len = j - i

        winner = data[j][2]['round_winner_by_cards']
        # print('winner: ', winner)

        # search for next reset after win to see how many chips were won.
        k = next((i for i, x in enumerate(data) if x[1] == 'RESET' and winner in (x[2]['name'], x[3]['name'], x[4]['name']) and i > j), None)
        if k is None:
            print("presumably last game. stopping because can't find next reset. data left: ", len(data))
            break
        new_chips = list(filter(lambda x: x['name'] == winner, data[k][2:]))[0]['chips']
        chips_won = new_chips - chips[winner]
        if chips_won < 0:
            chips_won = 8 # some default value because game was presumably reset
            n_winner_default_picked += 1

        # find out how many chips were lost by each player
        loser1, loser2 = [player['name'] for player in data[i][2:] if player['name'] != winner]

        # do this by searching for the next reset where they appear.
        k = next((i for i, x in enumerate(data) if x[1] == 'RESET' and loser1 in (x[2]['name'], x[3]['name'], x[4]['name']) and i > j), None)
        if k is None:
            loser1_chips = -4 # some default value
            n_losers_default_picked += 1
        else:
            k = next((i for i, x in enumerate(data) if x[1] == 'RESET' and loser1 in (x[2]['name'], x[3]['name'], x[4]['name']) and i > j), None)
            new_chips = list(filter(lambda x: x['name'] == loser1, data[k][2:]))[0]['chips']
            loser1_chips = new_chips - chips[loser1]
            if loser1_chips > 0:
                loser1_chips = -4 # some default value because game was presumably reset
                n_losers_default_picked += 1

        k = next((i for i, x in enumerate(data) if x[1] == 'RESET' and loser2 in (x[2]['name'], x[3]['name'], x[4]['name']) and i > j), None)
        if k is None:
            loser2_chips = -4 # some default value
            n_losers_default_picked += 1
        else:
            k = next((i for i, x in enumerate(data) if x[1] == 'RESET' and loser2 in (x[2]['name'], x[3]['name'], x[4]['name']) and i > j), None)
            new_chips = list(filter(lambda x: x['name'] == loser2, data[k][2:]))[0]['chips']
            loser2_chips = new_chips - chips[loser2]
            if loser2_chips > 0:
                loser2_chips = -4 # some default value because game was presumably reset
                n_losers_default_picked += 1
    
        weights = {winner: chips_won, loser1: loser1_chips, loser2: loser2_chips}
        for k in weights.keys():
            weights[k] = weights[k] / game_len # kinda normalize? by game length
        
        for event in data[i:j]:
            if event[1] != 'BET': continue
            for player_descr in event[2:]:
                potentially_new_action = Action(player_descr['bet'], player_descr['folded'])
                assert type(potentially_new_action.bet) is float
                if type(potentially_new_action.folded) != bool: # Hello, wtf?
                    assert potentially_new_action.folded in ('True', 'False')
                    potentially_new_action = potentially_new_action._replace(folded=potentially_new_action.folded == 'True')

                if potentially_new_action != last_actions[player_descr['name']]:
                    last_actions[player_descr['name']] = potentially_new_action
                    emit(
                        player_descr['face_player_cards'], # state that only player knows
                        player_descr['face_up_cards'], # state that everyone knows about player
                        set([tuple(x) for x in player_descr['all_cards']]) - set([tuple(x) for x in player_descr['face_up_cards']]), # state of rest of the table.
                        player_descr['chips'], # my chips
                        potentially_new_action, # action taken
                        weights[player_descr['name']] # Y to learn: how much did this action contribute to the win/loss
                    )


        data = data[j+1:]
        n_games += 1

    print('n_games:', n_games)
    print('n_losers_default_picked:', n_losers_default_picked)
    print('n_winner_default_picked:', n_winner_default_picked)
    print('training data size: ', len(training_data))
    # import pdb; pdb.set_trace()
    return training_data

def build_model():

    """
    Constructs a completely new model, using data to train. (WARNING: WILL OVERWRITE OLD MODEL FILE! BE CAREFUL)
    """

    # init topo of NN
    poker_nn = keras.Sequential([
        keras.layers.Dense(64, activation='sigmoid'),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dense(64, activation='relu'),
        keras.layers.Dense(1, activation='relu')
    ])

    # print("SUMMARY", poker_nn.summary())

    # since we are getting a probability from 0, 1
    # of winning this round, we will use BinaryCrossEntropy
    print("compiling model...")
    loss_fn = keras.losses.BinaryCrossentropy()
    poker_nn.compile(optimizer='adam',
                loss=loss_fn,
                metrics=loss_fn)

    # At this point we need to use our data to train the model!
    # We will split data into: x_train y_train (data, expected result),
    # and x_test, y_test (data_expected result)

    # training data will be used to adjust NN parameters, but the testing data
    # will be used to check the efficacy of the training (we will NOT fit the model
    # to this data whatsoever!)

    print("parsing training data...")
    # TODO: Use other methods to parse data into training vectors...
    converted_training_data = convert_training_data()

    full_x = np.array(converted_training_data[0])
    full_y = np.array(converted_training_data[1])

    # Note from Rishu: I am not entirely certain what convert_training_data() returns...
    # It appears to be returning a 1D array. What format is this array in...?

    np.array(list(map(, x)))
    print("x d-type:")
    print((full_x).dtype)
    print("x shape:")
    print(full_x.shape)

    print("y d-type:")
    print((full_y).dtype)
    print("y shape:")
    print(full_y.shape)

    x_train = None
    y_train = None
    x_test = None
    y_test = None

    if(x_train == None):
        print("implementation not complete. need to obtain training data first!")
        return

    # train the model using the data for 100 epochs
    poker_nn.fit(x_train, y_train, epochs=100)

    poker_nn.evaluate(x_test,  y_test, verbose=2)
    poker_nn.save("my_model.keras")

    print("SUMMARY", poker_nn.summary())


if __name__ == '__main__':
   build_model()
