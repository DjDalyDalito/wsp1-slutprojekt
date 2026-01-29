# Webbserverprogrammering 1 - Projekt #2
Enskillt projekt under andra halvan av höstterminen 2024 i kursen Webbserverprogrammering 1 på NTI Johanneberg.

## Uppgiftsbeskrivning
Du kommer att bygga en TODO-lista som en webbapplikation med av de tekniker vi har lärt oss i kursen Webbserverprogrammering. Under projektet kommer vi ha genomgångar för fler tekniker (som t.ex. inloggning). På vägen kommer du få kommer tips för hur du kan göra koden snyggare, bättre och lättare att hantera.

![Exempel på ToDo applikation](docs/img/todo-app.png)  
*Exempel på hur en ToDo-applikation kan se ut*

## Specifikation
- Webbapplikation i Ruby med Sinatra och SQLite.
- Individuellt projekt.
- Ta insipration från hur du gjorde i Fruktsidan (för att t.ex. skapa seeder-filen).
- Skapa en användare på Github med namnet: ntijoh-fornamn-efternamn.
- Forka detta repot: https://github.com/ntijoh-ola-lindberg/wsp1-todolistan och arbeta i för ditt projekt. Bjud in mig (ntijoh-ola-lindberg) till ditt repository.
- I slutet på varje lektion lägger ni upp koden ni skrivit till Github.
- Ni skriver i loggboken varje vecka.
- Ni får feedback av mig genom hela projektet. Främst på lektioner och i loggboken - kanske även via Github.
- Vid slutinlämning: Lämna in en liten film på classroom som visar applikationen.
- Bedömning: F/E enligt beskrivning: https://github.com/ntijoh/WTF24/blob/main/Bed%C3%B6mning%20Webbserver%201.md

## Installation

- Ladda ner de biblotek (tex. SQLite) du behöver med `bundle` (eller `bundle install` som är samma sak)
- Starta appen med `rake` Då körs även seed automatiskt ifall ingen databasfil finns.
- Kör seeder-filen med `rake seed` för att återställa databasen från seed-filen.

Använd verktyget SQLite Viewer: https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer eller DB Browser för att arbeta fram och testa SQL-kod.