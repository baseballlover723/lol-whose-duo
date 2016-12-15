var matches = {};
var groups = [];
if (gon.id) {
    App.main = App.cable.subscriptions.create({channel: "MainChannel", room: gon.id}, {
        connected: function () {
            console.log("connected");
            console.log(App.main);
        },
        disconnected: function () {
        },
        received: function (data) {
            console.log(data);
            if (!matches[data.summoner.summoner_id]) {
                matches[data.summoner.summoner_id] = [];
            }
            if (matches[data.summoner.summoner_id].indexOf(data.game.game_id) !== -1) {
                console.log("seen game before");
                return;
            }
            matches[data.summoner.summoner_id].push(data.game.game_id);
            console.log(matches);
            addGame(data.summoner, data.game, data.summoners);
            update();
        }
    });
}

function addGame(summoner, game, summoners) {
    groups.push({summoners: [], totalGames: 10});
    groups[0].summoners.push({summoner: summoners[1], gamesInGroup: 10});
    groups[0].summoners.push({summoner: summoners[2], gamesInGroup: 5});
    groups[0].summoners.push({summoner: summoners[3], gamesInGroup: 1});
}
function update() {
    // group into groups
    // % chance of being in the group is the number of matches played with other group members / number of matches in group
    $("#groups").empty();
    for (var group in groups) {
        group = groups[group];
        var totalGames = group.totalGames;

        var groupDom = $('<div>');
        groupDom.text('group');
        console.log(group.summoners);
        for (var obj in group.summoners) {
            obj = group.summoners[obj];
            var gamesInGroup = obj.gamesInGroup;
            var confidence = gamesInGroup / totalGames;
            var summoner = obj.summoner;
            console.log(summoner);
            console.log(summoner.username + ": " + confidence * 100 + "%");
        }
        $("#groups").append(groupDom);

    }
}
