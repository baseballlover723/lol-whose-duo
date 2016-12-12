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
        }
    });
}