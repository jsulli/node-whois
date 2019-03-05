const path = require('path');
const outputDirectory = 'dist';


module.exports = {
    entry: [
        './app.js'
    ],
    output: {
        path: path.join(__dirname, outputDirectory),
        filename: 'bundle.js'
    },
    module: {
        rules: [
            {
                test: /node_modules[/\\]whois/i
                , loader: 'shebang-loader'
            },
            {
                test: /\.html/,
                exclude: /(node_modules|bower_components)/,
                use: [ {
                    loader: 'file-loader',
                    options: { name: '[name].[ext]' },
                }],
            },
        ]
    },
    resolve: {
        extensions: ['.js']
    },
    target: 'node',
}