const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sendgrid = require("@sendgrid/mail");
const cors = require("cors")({ origin: true });

admin.initializeApp();

sendgrid.setApiKey(functions.config().sendgrid.key);

exports.sendCsvToEmail = functions.https.onCall((req, res) => {
  cors(req, res, async () => {

    const { email, csvData, name } = req.body;

    if (!email || !csvData || typeof csvData !== "string") {
      return res.status(400).send("Missing or invalid email/csvData");
    }

    try {
      const msg = {
        to: email,
        from: "juniorwilliamt@gmail.com",
        subject: "Laporan Transaksi",
        text: "Berikut adalah laporan transaksi dalam format CSV.",
        attachments: [
          {
            filename: `Report_${name}.csv`,
            content: Buffer.from(csvData).toString("base64"),
            type: "csv",
            disposition: "attachment",
          },
        ],
      };

      await sendgrid.send(msg);
      res.status(200).send("Email sent successfully");
    } catch (err) {
      console.error("Send error", err);
      res.status(500).send("Send error");
    }
  });
});
