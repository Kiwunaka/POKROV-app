Production builders stage the approved `candidate-ranker-v1.bin` here from
`CandidateRankerModelPath`. The fixed PKRTF001/F82 weights are an ignored build
input, never a committed binary. An ordinary source checkout may omit them;
production packaging requires and verifies the actual bundled model.
