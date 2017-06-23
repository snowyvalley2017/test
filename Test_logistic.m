clear ; close all; clc

% refer to ex2&3 logistic regression codes

train = load('trainL.csv');
test = load('testL.csv');
valid = load('validL.csv');


y = train(:,2); X = train(:,3:99);

y_t = test(:,2); X_t = test(:,3:99);

yval = valid(:,2); Xval = valid(:,3:99);

item_t = test(:,1);

%  Setup the data matrix appropriately, and add ones for the intercept term
[m, n] = size(X);

[m_t, n_t] = size(X_t);

[mval, nval] = size(Xval);

% Add intercept term to x and X_test
X = [ones(m, 1) X];

X_t = [ones(m_t, 1) X_t];

Xval = [ones(mval, 1) Xval];
% Initialize fitting parameters
initial_theta = zeros(n + 1, 1);


% lrCostFunction
fprintf('\nTesting lrCostFunction()');

lambda = 1;
[J, grad] = lrCostFunction(initial_theta, X, y, lambda);

%fprintf('\nCost: %f\n', J);
%fprintf('Gradients:\n');
%fprintf(' %f \n', grad);
%fprintf('Program paused. Press enter to continue.\n');
%pause;

%% ============= Part 3: Optimizing using fminunc  =============
%  In this exercise, you will use a built-in function (fminunc) to find the
%  optimal parameters theta.

%  Set options for fminunc
options = optimset('GradObj', 'on', 'MaxIter', 400);

%  Run fminunc to obtain the optimal theta
%  This function will return theta and the cost 
[theta, cost] = ...
	fminunc(@(t)(lrCostFunction(t, X, y, lambda)), initial_theta, options);

% Print theta to screen
%fprintf('Cost at theta found by fminunc: %f\n', cost);
%fprintf('theta: \n');
%fprintf(' %f \n', theta);
%pause;

%% ============== Part 4: Predict and Accuracies ==============
%  After learning the parameters, you'll like to use it to predict the outcomes
%  on unseen data. In this part, you will use the logistic regression model
%  to predict the probability that a student with score 45 on exam 1 and 
%  score 85 on exam 2 will be admitted.
%
%  Furthermore, you will compute the training and test set accuracies of 
%  our model.
%
%  Your task is to complete the code in predict.m

%  Predict probability for a student with score 45 on exam 1 
%  and score 85 on exam 2 


prob = sigmoid(X_t * theta);
% Compute accuracy on our training set
p = predictlr(theta, X_t);
fprintf('Test Accuracy: %f\n', mean(double(p == y_t)) * 100); 
%Previous Test Accuracy: 71.597479
err_test=lrCostFunction(theta, X_t, y_t, lambda);

prob_train = sigmoid(X * theta);
% Compute accuracy on our training set
p_train = predictlr(theta, X);
fprintf('Train Accuracy: %f\n', mean(double(p_train == y)) * 100); 
%Previous Train Accuracy: 71.847252

score = [item_t, prob];

save score_log.txt score;