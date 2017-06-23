%% Initialization
clear ; close all; clc

%% =========== Part 1: Loading and Visualizing Data =============
%  We start the exercise by first loading and visualizing the dataset. 
%  The following code will load the dataset into your environment and plot
%  the data.
%

% Load Training Data


% Load from train: 
% You will have X, y, Xval, yval, X_t, y_t in your environment

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
%% =========== Part 2&3: Regularized Linear Regression Cost * Gradient =============
%  You should now implement the cost function for regularized linear 
%  regression. 

% lrCostFunction
fprintf('\nTesting lrCostFunction()');
% Initialize fitting parameters
initial_theta = zeros(n + 1, 1);



lambda = 1;
[J, grad] = lrCostFunction(initial_theta, X, y, lambda);


%% =========== Part 4: Train  Regression =============
%  Once you have implemented the cost and gradient correctly, the
%  trainLinearReg function will use your cost function to train 
%  regularized linear regression.
% 
%  Write Up Note: The data is non-linear, so this will not give a great 
%                 fit.
%%  Train linear regression with lambda = 0
lambda = 0;
[theta] = trainLogReg(X, y, lambda);



%% =========== Part 5: Learning Curve for  Regression =============
%  Next, you should implement the learningCurve function. 
%
%
lambda = 0;
[error_train, error_val] = learningCurve_log(X, y, Xval, yval, lambda);

plot(1:2000, error_train, 1:2000, error_val);
title('Learning curve for logistic regression')
legend('Train', 'Cross Validation')
xlabel('Number of training examples')
ylabel('Error')
axis([215 2000 0 10])

fprintf('# Training Examples\tTrain Error\tCross Validation Error\n');
for i = 1:2000
    fprintf('  \t%d\t\t%f\t%f\n', i, error_train(i), error_val(i));
end


%plot accuracy rate change

lambda = 0;
[error_train, error_val] = learningCurveLR_AR(X, y, Xval, yval, lambda);

plot(1:2000, error_train, 1:2000, error_val);
title('Learning curve for logistic regression')
legend('Train', 'Cross Validation')
xlabel('Number of training examples')
ylabel('Accuracy')
axis([0 2000 0 100])

fprintf('# Training Examples\tTrain Error\tCross Validation Error\n');
for i = 1:2000
    fprintf('  \t%d\t\t%f\t%f\n', i, error_train(i), error_val(i));
end



% Compute accuracy on our training set
p = predict(theta, Xval);

fprintf('Train Accuracy: %f\n', mean(double(p == yval)) * 100); 
%Previous Train Accuracy:  71.827833
fprintf('\n');

save theta_log.txt theta;

a = [yval,p];

save freq.txt a;
